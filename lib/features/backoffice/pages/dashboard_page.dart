import 'package:flutter/material.dart';

import '../data/backoffice_store.dart';
import '../data/seed_data.dart';
import '../theme.dart';
import '../widgets/bar_chart.dart';
import '../widgets/kpi_card.dart';

const List<double> _revenueValues = [3.2, 4.1, 3.8, 4.6, 5.2, 5.8];
const List<String> _revenueLabels = ['Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août'];
const List<double> _weekValues = [3, 4, 5, 2, 6, 4, 5];
const List<String> _weekLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

/// Dashboard page: KPI carousel, charts and the activity feed.
class BoDashboardPage extends StatelessWidget {
  const BoDashboardPage({super.key, required this.store});

  final BackofficeStore store;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 6, bottom: 110),
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final revenus = store.revenusMilliers.round();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- KPI carousel (height adapts to the tallest card) ---
              IntrinsicHeight(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BoKpiCard(
                        icon: Icons.group_outlined,
                        iconColor: BackofficeTheme.green,
                        iconBg: BackofficeTheme.greenSoft,
                        trend: '↑4.2%',
                        trendUp: true,
                        value: '${store.clientsActifs}',
                        label: 'Clients actifs',
                      ),
                      const SizedBox(width: 10),
                      BoKpiCard(
                        icon: Icons.event_available_outlined,
                        iconColor: BackofficeTheme.goldDim,
                        iconBg: BackofficeTheme.goldSoft,
                        trend: '↑12',
                        trendUp: true,
                        value: '${store.collectesAujourdhui}',
                        label: "Collectes aujourd'hui",
                      ),
                      const SizedBox(width: 10),
                      BoKpiCard(
                        icon: Icons.payments_outlined,
                        iconColor: BackofficeTheme.blue,
                        iconBg: BackofficeTheme.blueSoft,
                        trend: '↑8.7%',
                        trendUp: true,
                        value: '₣$revenus',
                        label: 'Revenus (milliers)',
                      ),
                      const SizedBox(width: 10),
                      BoKpiCard(
                        icon: Icons.trending_up_rounded,
                        iconColor: BackofficeTheme.red,
                        iconBg: BackofficeTheme.redSoft,
                        trend: '↓1.1%',
                        trendUp: false,
                        value: '${store.tauxReussite.round()}%',
                        label: 'Taux de réussite',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),
              _chartCard('Revenus (6 mois)', 'XAF, milliers',
                  BoBarChart(values: _revenueValues, labels: _revenueLabels)),
              _chartCard('Collectes — 7 derniers jours', null,
                  BoBarChart(values: _weekValues, labels: _weekLabels)),

              _SectionTitle(title: 'Activité récente', trailing: 'Temps réel'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BackofficeTheme.card(),
                child: Column(
                  children: [
                    for (var i = 0; i < seedActivity.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: BackofficeTheme.border),
                      _FeedItem(
                        color: _parseColor(seedActivity[i].color),
                        text: seedActivity[i].text,
                        time: seedActivity[i].time,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chartCard(String title, String? tag, Widget chart) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BackofficeTheme.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BackofficeTheme.inter(12.5, weight: FontWeight.w600),
                ),
              ),
              if (tag != null) ...[
                const SizedBox(width: 8),
                Text(
                  tag,
                  style: BackofficeTheme.inter(10.5, color: BackofficeTheme.muted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          chart,
        ],
      ),
    );
  }

  Color _parseColor(String hex) => Color(int.parse(hex.replaceFirst('#', '0xFF')));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: BackofficeTheme.sora(14, weight: FontWeight.w700)),
          Text(trailing, style: BackofficeTheme.inter(11, color: BackofficeTheme.muted)),
        ],
      ),
    );
  }
}

class _FeedItem extends StatelessWidget {
  const _FeedItem({required this.color, required this.text, required this.time});

  final Color color;
  final String text;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: BackofficeTheme.inter(12, weight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(time, style: BackofficeTheme.inter(10.5, color: BackofficeTheme.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
