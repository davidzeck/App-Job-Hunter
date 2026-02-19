import 'package:flutter/material.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/mock_api_service.dart';
import 'package:job_scout/core/theme/app_theme.dart';
import 'package:job_scout/core/widgets/job_card.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _api = MockApiService();
  final _searchController = TextEditingController();

  List<JobListItem> _jobs = [];
  bool _loading = true;
  String? _locationType;
  int _daysAgo = 7;

  static const _dayOptions = [1, 3, 7, 14, 30];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() => _loading = true);
    final result = await _api.getJobs(
      role: _searchController.text.isNotEmpty ? _searchController.text : null,
      locationType: _locationType,
      daysAgo: _daysAgo,
      limit: 50,
    );
    setState(() {
      _jobs = result.items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadJobs,
        color: AppColors.primaryBlue,
        child: CustomScrollView(
          slivers: [
            // ─── App Bar ─────────────────────────────
            SliverAppBar(
              floating: true,
              title: Text(
                'Jobs',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadJobs(),
                    decoration: InputDecoration(
                      hintText: 'Search by role or keyword...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadJobs();
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ─── Filter Chips ────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location type
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _locationType == null,
                            onSelected: () {
                              setState(() => _locationType = null);
                              _loadJobs();
                            },
                          ),
                          _FilterChip(
                            label: 'Remote',
                            selected: _locationType == 'remote',
                            onSelected: () {
                              setState(() => _locationType = 'remote');
                              _loadJobs();
                            },
                          ),
                          _FilterChip(
                            label: 'Hybrid',
                            selected: _locationType == 'hybrid',
                            onSelected: () {
                              setState(() => _locationType = 'hybrid');
                              _loadJobs();
                            },
                          ),
                          _FilterChip(
                            label: 'On-site',
                            selected: _locationType == 'onsite',
                            onSelected: () {
                              setState(() => _locationType = 'onsite');
                              _loadJobs();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Days ago
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _dayOptions.map((d) {
                          return _FilterChip(
                            label: d == 1 ? 'Today' : 'Last $d days',
                            selected: _daysAgo == d,
                            onSelected: () {
                              setState(() => _daysAgo = d);
                              _loadJobs();
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Results Count ───────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  _loading ? 'Loading...' : '${_jobs.length} jobs found',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.mutedForegroundDark
                        : AppColors.mutedForegroundLight,
                  ),
                ),
              ),
            ),

            // ─── Job List ────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_jobs.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: isDark
                            ? AppColors.mutedForegroundDark
                            : AppColors.mutedForegroundLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No jobs match your filters',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark
                              ? AppColors.mutedForegroundDark
                              : AppColors.mutedForegroundLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _locationType = null;
                            _daysAgo = 30;
                            _searchController.clear();
                          });
                          _loadJobs();
                        },
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => JobCard(
                    job: _jobs[index],
                    animationIndex: index,
                  ),
                  childCount: _jobs.length,
                ),
              ),

            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
      ),
    );
  }
}
