import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/providers/jobs_filter_provider.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';
import 'package:job_scout/core/widgets/error_state.dart';
import 'package:job_scout/core/widgets/job_card.dart';
import 'package:job_scout/core/widgets/skeleton_loader.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _api = api;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  JobsFilterProvider? _jobsFilter;

  List<JobListItem> _jobs = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _locationType;
  int _daysAgo = 7;
  int _page = 1;
  int _totalPages = 1;
  Timer? _debounce;

  static const _limit = 5; // small limit so pagination is visible with mock data
  static const _dayOptions = [1, 3, 7, 14, 30];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _jobsFilter = context.read<JobsFilterProvider>();
      _jobsFilter!.addListener(_onCompanyFilterChanged);
      _loadJobs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    _jobsFilter?.removeListener(_onCompanyFilterChanged);
    super.dispose();
  }

  void _onCompanyFilterChanged() {
    if (mounted) _resetAndLoad();
  }

  // ─── Search debounce ─────────────────────────────

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _resetAndLoad();
    });
  }

  // ─── Scroll-to-bottom pagination ─────────────────

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  // ─── Load (reset to page 1) ───────────────────────

  Future<void> _loadJobs() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final companySlug = _jobsFilter?.companySlug;
      final result = await _api.getJobs(
        companySlugs: companySlug != null ? [companySlug] : null,
        role: _searchController.text.isNotEmpty ? _searchController.text : null,
        locationType: _locationType,
        daysAgo: _daysAgo,
        page: 1,
        limit: _limit,
      );
      if (mounted) {
        setState(() {
          _jobs = result.items;
          _totalPages = result.pages;
          _page = 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load jobs. Tap to retry.';
          _loading = false;
        });
      }
    }
  }

  void _resetAndLoad() {
    _scrollController.jumpTo(0);
    _loadJobs();
  }

  // ─── Load next page ───────────────────────────────

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    try {
      final companySlug = _jobsFilter?.companySlug;
      final result = await _api.getJobs(
        companySlugs: companySlug != null ? [companySlug] : null,
        role: _searchController.text.isNotEmpty ? _searchController.text : null,
        locationType: _locationType,
        daysAgo: _daysAgo,
        page: _page + 1,
        limit: _limit,
      );
      if (mounted) {
        setState(() {
          _jobs = [..._jobs, ...result.items];
          _page = result.page;
          _totalPages = result.pages;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final jobsFilter = context.watch<JobsFilterProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadJobs,
        color: AppColors.primaryBlue,
        child: CustomScrollView(
          controller: _scrollController,
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
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _resetAndLoad(),
                    decoration: InputDecoration(
                      hintText: 'Search by role or keyword...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _resetAndLoad();
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _locationType == null,
                            onSelected: () {
                              setState(() => _locationType = null);
                              _resetAndLoad();
                            },
                          ),
                          _FilterChip(
                            label: 'Remote',
                            selected: _locationType == 'remote',
                            onSelected: () {
                              setState(() => _locationType = 'remote');
                              _resetAndLoad();
                            },
                          ),
                          _FilterChip(
                            label: 'Hybrid',
                            selected: _locationType == 'hybrid',
                            onSelected: () {
                              setState(() => _locationType = 'hybrid');
                              _resetAndLoad();
                            },
                          ),
                          _FilterChip(
                            label: 'On-site',
                            selected: _locationType == 'onsite',
                            onSelected: () {
                              setState(() => _locationType = 'onsite');
                              _resetAndLoad();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _dayOptions.map((d) {
                          return _FilterChip(
                            label: d == 1 ? 'Today' : 'Last $d days',
                            selected: _daysAgo == d,
                            onSelected: () {
                              setState(() => _daysAgo = d);
                              _resetAndLoad();
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    if (jobsFilter.hasCompanyFilter)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            FilterChip(
                              label: Text(jobsFilter.companyName ?? ''),
                              selected: true,
                              onSelected: (_) {},
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () =>
                                  _jobsFilter?.clearCompanyFilter(),
                              showCheckmark: false,
                              avatar: const Icon(Icons.business, size: 14),
                            ),
                          ],
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
                  _loading
                      ? 'Searching...'
                      : _error != null
                          ? ''
                          : '${_jobs.length} jobs found',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.mutedForegroundDark
                        : AppColors.mutedForegroundLight,
                  ),
                ),
              ),
            ),

            // ─── States ──────────────────────────────
            if (_loading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const SkeletonJobCard(),
                  childCount: 6,
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: ErrorStateWidget(
                  message: _error!,
                  onRetry: _loadJobs,
                ),
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
                          if (_jobsFilter?.hasCompanyFilter == true) {
                            // clearCompanyFilter notifies listeners →
                            // _onCompanyFilterChanged → _resetAndLoad
                            _jobsFilter!.clearCompanyFilter();
                          } else {
                            _resetAndLoad();
                          }
                        },
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => JobCard(
                    job: _jobs[index],
                    animationIndex: index,
                  ),
                  childCount: _jobs.length,
                ),
              ),

              // ─── Load More Indicator ─────────────
              SliverToBoxAdapter(
                child: _page < _totalPages
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: _loadingMore
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.primaryBlue,
                                  ),
                                )
                              : Text(
                                  'Scroll for more',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? AppColors.mutedForegroundDark
                                        : AppColors.mutedForegroundLight,
                                  ),
                                ),
                        ),
                      )
                    : const SizedBox(height: 8),
              ),
            ],

            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Chip ───────────────────────────────────────────────

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
