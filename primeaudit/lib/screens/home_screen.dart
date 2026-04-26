import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_roles.dart';
import '../core/app_theme.dart';
import '../models/audit.dart';
import '../services/audit_service.dart';
import '../services/auth_service.dart';
import '../services/company_context_service.dart';
import '../services/dashboard_service.dart';
import '../services/user_service.dart';
import 'admin/admin_screen.dart';
import 'audits_screen.dart';
import 'corrective_actions_screen.dart';
import '../services/corrective_action_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'templates/audit_types_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  final _auditService = AuditService();
  final _dashboardService = DashboardService();
  final _correctiveActionService = CorrectiveActionService();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _role = '';
  String _name = '';
  String _email = '';
  bool _loading = true;
  int _totalAudits = 0;
  int _pendingAudits = 0;
  int _overdueAudits = 0;
  int _openActions = 0;
  int _companiesCount = 0;
  List<_TemplateConformity> _chartData = [];
  bool _dashboardLoading = false;
  String? _dashboardError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      final profile = await _userService.getById(user.id);
      await CompanyContextService.instance.init(
        role: profile.role,
        profileCompanyId: profile.companyId,
        profileCompanyName: profile.companyName,
      );
      if (mounted) {
        setState(() {
          _role = profile.role;
          _name = profile.fullName;
          _email = profile.email;
        });
      }
      await _loadDashboard(); // chain: _role and CompanyContextService now ready
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() {
      _dashboardLoading = true;
      _dashboardError = null;
    });
    try {
      final companyId = CompanyContextService.instance.activeCompanyId;
      final currentUserId = _authService.currentUser?.id ?? '';

      // Single fetch — Dart-side filter for auditor scope (D-05/D-06)
      final all = await _auditService.getAudits(companyId: companyId);
      final audits = (AppRole.isSuperOrDev(_role) || AppRole.canAccessAdmin(_role))
          ? all
          : all.where((a) => a.auditorId == currentUserId).toList();

      // KPI counts in Dart (D-01: total excludes cancelada, D-02: pending = emAndamento, D-03: overdue = atrasada)
      final total = audits.where((a) => a.status != AuditStatus.cancelada).length;
      final pending = audits.where((a) => a.status == AuditStatus.emAndamento).length;
      final overdue = audits.where((a) => a.status == AuditStatus.atrasada).length;

      // Open actions — aberta + em_andamento + em_avaliacao (Phase 8)
      final openActions = await _correctiveActionService.getOpenActionsCount(companyId);

      // Companies count — superuser/dev only (D-07: isSuperOrDev, NOT canAccessAdmin)
      int companiesCount = 0;
      if (AppRole.isSuperOrDev(_role)) {
        companiesCount = await _dashboardService.getCompaniesCount();
      }

      // Chart data aggregation (concluida audits only, grouped by template, sorted best-first)
      final chartData = _buildChartData(audits);

      if (mounted) {
        setState(() {
          _totalAudits = total;
          _pendingAudits = pending;
          _overdueAudits = overdue;
          _openActions = openActions;
          _companiesCount = companiesCount;
          _chartData = chartData;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dashboardError =
            'Erro ao carregar dashboard. Puxe a tela para baixo para tentar novamente.');
      }
    } finally {
      if (mounted) setState(() => _dashboardLoading = false);
    }
  }

  List<_TemplateConformity> _buildChartData(List<Audit> audits) {
    final Map<String, List<double>> byTemplate = {};
    for (final a in audits) {
      if (a.status == AuditStatus.concluida && a.conformityPercent != null) {
        byTemplate.putIfAbsent(a.templateName, () => []).add(a.conformityPercent!);
      }
    }
    return byTemplate.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return _TemplateConformity(e.key, avg);
    }).toList()
      ..sort((a, b) => b.avgConformity.compareTo(a.avgConformity));
  }

  Future<void> _logout() async {
    Navigator.of(context).pop(); // fecha o drawer
    await CompanyContextService.instance.clear();
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _navigate(Widget screen) {
    Navigator.of(context).pop(); // fecha o drawer
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.of(context).background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('PrimeAudit',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {}, // futuro
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _buildDashboard(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.of(context).surface,
      child: Column(
        children: [
          // Cabeçalho do drawer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 14),
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white24,
                  child: Text(
                    _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name.isNotEmpty ? _name : 'Usuário',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _email,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppRole.label(_role),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Itens do menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(
                  icon: Icons.dashboard_rounded,
                  title: 'Dashboard',
                  onTap: () => Navigator.of(context).pop(),
                ),
                if (AppRole.canAccessAdmin(_role))
                  _drawerItem(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Administração',
                    onTap: () => _navigate(const AdminScreen()),
                  ),
                if (AppRole.canAccessAdmin(_role))
                  _drawerItem(
                    icon: Icons.assignment_rounded,
                    title: 'Templates de Auditoria',
                    onTap: () => _navigate(const AuditTypesScreen()),
                  ),
                _drawerItem(
                  icon: Icons.playlist_add_check_rounded,
                  title: 'Auditorias',
                  onTap: () => _navigate(AuditsScreen(
                    currentUserId: _authService.currentUser?.id ?? '',
                    currentUserName: _name,
                  )),
                ),
                _drawerItem(
                  icon: Icons.assignment_late_outlined,
                  title: 'Ações Corretivas',
                  badgeCount: _openActions,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                          builder: (_) => CorrectiveActionsScreen(
                            currentUserId:
                                _authService.currentUser?.id ?? '',
                            currentUserRole: _role,
                          ),
                        ))
                        .then((_) => _loadDashboard());
                  },
                ),
                _drawerItem(
                  icon: Icons.bar_chart_rounded,
                  title: 'Relatórios',
                  onTap: () => Navigator.of(context).pop(), // próxima tela
                ),
                const Divider(indent: 16, endIndent: 16),
                _drawerItem(
                  icon: Icons.person_outline_rounded,
                  title: 'Meu perfil',
                  onTap: () => _navigate(const ProfileScreen()),
                ),
                _drawerItem(
                  icon: Icons.settings_outlined,
                  title: 'Configurações',
                  onTap: () => _navigate(const SettingsScreen()),
                ),
              ],
            ),
          ),

          // Rodapé com logout
          const Divider(height: 1),
          _drawerItem(
            icon: Icons.logout_rounded,
            title: 'Sair',
            color: AppColors.error,
            onTap: _logout,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    int badgeCount = 0,
  }) {
    final itemColor = color ?? AppTheme.of(context).textPrimary;
    Widget iconWidget = Icon(icon, color: itemColor, size: 22);
    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text('$badgeCount'),
        child: iconWidget,
      );
    }
    return ListTile(
      onTap: onTap,
      leading: iconWidget,
      title: Text(
        title,
        style: TextStyle(
          color: itemColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      horizontalTitleGap: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saudação
            Text(
              _name.isNotEmpty
                  ? 'Olá, ${_name.split(' ').first}!'
                  : 'Bem-vindo!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.of(context).textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _roleLabel(),
              style: TextStyle(
                  fontSize: 13, color: AppTheme.of(context).textSecondary),
            ),
            const SizedBox(height: 24),

            // Linha 1: Total + Pendentes
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    icon: Icons.assignment_rounded,
                    label: 'Total',
                    value: _dashboardLoading ? '...' : '$_totalAudits',
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCard(
                    icon: Icons.pending_rounded,
                    label: 'Pendentes',
                    value: _dashboardLoading ? '...' : '$_pendingAudits',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Linha 2: Atrasadas + Ações abertas (ou Empresas para superuser/dev)
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    icon: Icons.warning_rounded,
                    label: 'Atrasadas',
                    value: _dashboardLoading ? '...' : '$_overdueAudits',
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 8),
                // D-07: isSuperOrDev (NOT canAccessAdmin) for Empresas card
                Expanded(
                  child: AppRole.isSuperOrDev(_role)
                      ? _summaryCard(
                          icon: Icons.business_rounded,
                          label: 'Empresas',
                          value: _dashboardLoading ? '...' : '$_companiesCount',
                          color: Colors.purple,
                        )
                      : _summaryCard(
                          // D-04: always render, value 0 until Phase 8 creates corrective_actions
                          icon: Icons.task_alt_rounded,
                          label: 'Ações abertas',
                          value: _dashboardLoading ? '...' : '$_openActions',
                          color: Colors.teal,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Gráfico de conformidade por template (DASH-03)
            if (_dashboardError != null) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.of(context).divider),
                ),
                child: Text(
                  _dashboardError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.of(context).textSecondary, fontSize: 13),
                ),
              ),
            ] else ...[
              Text(
                'Conformidade por template',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.of(context).textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildConformityChart(_chartData),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConformityChart(List<_TemplateConformity> data) {
    if (data.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.of(context).surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.of(context).divider),
        ),
        child: Text(
          'Nenhuma auditoria concluída para exibir',
          style: TextStyle(
              color: AppTheme.of(context).textSecondary, fontSize: 13),
        ),
      );
    }

    return SizedBox(
      height: data.length * 48.0 + 40,
      child: BarChart(
        BarChartData(
          rotationQuarterTurns: 1,
          maxY: 100,
          barGroups: List.generate(
            data.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].avgConformity,
                  color: AppColors.primary,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          titlesData: FlTitlesData(
            // With rotationQuarterTurns:1, the left axis becomes the bar labels axis
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 120,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    data[idx].templateName,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.of(context).textSecondary),
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}%',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.of(context).textSecondary),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
        ),
      ),
    );
  }

  String _roleLabel() {
    switch (_role) {
      case AppRole.superuser:
        return 'Acesso total ao sistema';
      case AppRole.dev:
        return 'Ambiente de desenvolvimento';
      case AppRole.adm:
        return 'Administrador da empresa';
      case AppRole.auditor:
        return 'Auditor';
      case AppRole.anonymous:
        return 'Acesso restrito';
      default:
        return '';
    }
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.of(context).divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.of(context).textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.of(context).textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dados de conformidade média por template para o gráfico de barras.
class _TemplateConformity {
  final String templateName;
  final double avgConformity; // 0.0–100.0

  const _TemplateConformity(this.templateName, this.avgConformity);
}
