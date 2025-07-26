import 'package:flutter/material.dart';
import '../widgets/spin_history_list.dart';
import '../widgets/withdrawal_history_list.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Le decimos al controlador que nos avise cuando cambia la pestaña para redibujar
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.history_edu_outlined,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Tu Historial',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.secondary,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Theme.of(context).colorScheme.secondary,
                labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/rueda-de-la-fortuna.png',
                          height: 24,
                          width: 24,
                          color: _tabController.index == 0
                              ? Theme.of(context).colorScheme.secondary
                              : (isDarkMode ? Colors.grey.shade400 : null),
                        ),
                        const SizedBox(height: 4),
                        const Text('Historial de Giros',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off),
                        SizedBox(height: 4),
                        Text('Historial de Retiros',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    SpinHistoryView(),
                    WithdrawalHistoryView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}