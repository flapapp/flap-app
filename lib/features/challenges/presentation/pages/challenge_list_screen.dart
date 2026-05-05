import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../router/app_router.dart';
import '../../../../core/di/injection.dart';
import '../../domain/repositories/challenges_repository.dart';
import '../../data/models/challenge.dart';
import '../../../../widgets/player_avatar_button.dart';

@RoutePage()
class ChallengeListScreen extends StatefulWidget {
  const ChallengeListScreen({super.key});

  @override
  State<ChallengeListScreen> createState() => _ChallengeListScreenState();
}

class _ChallengeListScreenState extends State<ChallengeListScreen> {
  ChallengesRepository get _challengesRepo => sl<ChallengesRepository>();

  String _selectedStatus = 'all';
  String _selectedType = 'all';
  String _selectedCity = '';
  String _searchQuery = '';

  final List<String> _statuses = [
    'all',
    'recruiting',
    'submission',
    'voting',
    'completed',
  ];

  final List<String> _types = [
    'all',
    'goal',
    'shot_power',
    'pass',
    'long_pass',
    'dribbling',
    'tackle',
    'penalty',
    'save',
    'wall',
    'strategy',
    'trick',
    'other',
  ];

  List<String> get _cities => [
    tr('all_cities'),
    tr('kyiv'),
    tr('kharkiv'),
    tr('odesa'),
    tr('dnipro'),
    tr('lviv'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e7d32),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr('il_71690bd800'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () => _showCreateChallenge(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filters
            _buildFilters(),

            // Challenge list
            Expanded(child: _buildChallengesList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateChallenge(),
        backgroundColor: const Color(0xFFFF9800),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: tr('il_a15fecd2a4'),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Search
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(15),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: tr('il_062314f3ab'),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                suffixIcon: Icon(Icons.search, color: Colors.grey[600]),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // Filters row
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  _statuses.map((s) => _getStatusText(s)).toList(),
                  _statuses,
                  _selectedStatus,
                  (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                  '📊',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFilterDropdown(
                  _types.map((t) => _getTypeText(t)).toList(),
                  _types,
                  _selectedType,
                  (value) {
                    setState(() {
                      _selectedType = value;
                    });
                  },
                  '🎯',
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // Filter by city
          _buildFilterDropdown(
            _cities,
            _cities.map((c) => c == tr('all_cities') ? '' : c).toList(),
            _selectedCity,
            (value) {
              setState(() {
                _selectedCity = value;
              });
            },
            '🏙️',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    List<String> displayItems,
    List<String> values,
    String selectedValue,
    Function(String) onChanged,
    String icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue.isEmpty ? null : selectedValue,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          hint: Row(
            children: [
              Text(icon),
              const SizedBox(width: 8),
              Expanded(child: Text(tr('all'))),
            ],
          ),
          items: displayItems.asMap().entries.map((entry) {
            final index = entry.key;
            final displayItem = entry.value;
            final value = values[index];

            return DropdownMenuItem<String>(
              value: value,
              child: Row(
                children: [
                  Text(icon),
                  const SizedBox(width: 8),
                  Expanded(child: Text(displayItem)),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildChallengesList() {
    return StreamBuilder<List<Challenge>>(
      stream: _getFilteredChallengesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              tr('il_24ffa7c8c5', args: [snapshot.error?.toString() ?? '']),
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final challenges = snapshot.data ?? [];

        if (challenges.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  tr('il_535b6a64c4'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('il_5a60646d87'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _showCreateChallenge(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    tr('il_a15fecd2a4'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            final challenge = challenges[index];
            return _buildChallengeCard(challenge);
          },
        );
      },
    );
  }

  Widget _buildChallengeCard(Challenge challenge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openChallengeDetails(challenge),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and type
                Row(
                  children: [
                    Text(
                      challenge.typeIcon,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            challenge.typeText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Color(challenge.statusColor).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(challenge.statusColor).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        challenge.statusText,
                        style: TextStyle(
                          color: Color(challenge.statusColor),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // Description
                if (challenge.description.isNotEmpty) ...[
                  Text(
                    challenge.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 15),
                ],

                // Stats
                Row(
                  children: [
                    _buildStatItem(
                      '👥',
                      '${challenge.currentParticipants}/${challenge.maxParticipants}',
                    ),
                    const SizedBox(width: 20),
                    _buildStatItem('🎬', '${challenge.submissions.length}'),
                    const SizedBox(width: 20),
                    _buildStatItem(
                      '💰',
                      '${challenge.prizePool.toInt()} ${tr('il_62f014cb31')}',
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Audience and entry fee
                Row(
                  children: [
                    _buildStatItem(
                      challenge.audienceIcon,
                      challenge.audienceText,
                    ),
                    const SizedBox(width: 20),
                    _buildStatItem(
                      '💸',
                      '${tr('il_861e39505d')} ${challenge.entryFee} ${tr('il_62f014cb31')}',
                    ),
                    const SizedBox(width: 20),
                    _buildStatItem(
                      '⏰',
                      challenge.durationDisplayLabel,
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // Progress bar
                _buildProgressBar(challenge),

                const SizedBox(height: 15),

                // Creator and time
                Row(
                  children: [
                    PlayerAvatarButton(
                      userId: challenge.creatorId,
                      displayName: challenge.creatorName,
                      size: 32,
                      backgroundColor: const Color(0xFFFF9800),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge.creatorName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${challenge.city} • ${_formatDate(challenge.createdAt)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildTimeRemaining(challenge),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(Challenge challenge) {
    double progress = 0.0;
    String progressText = '';

    switch (challenge.status) {
      case ChallengeStatus.recruiting:
        progress = challenge.recruitmentProgress;
        progressText = tr('il_a0d55310f8');
        break;
      case ChallengeStatus.submission:
        progress = challenge.submissionProgress;
        progressText = tr('il_fefdc339a9');
        break;
      case ChallengeStatus.voting:
        progress = challenge.votingProgress;
        progressText = tr('il_aca2f665db');
        break;
      case ChallengeStatus.completed:
        progress = 1.0;
        progressText = tr('il_22a970d2e5');
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              progressText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            Color(challenge.statusColor),
          ),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildTimeRemaining(Challenge challenge) {
    Duration timeRemaining;
    String timeText = '';
    Color timeColor = Colors.grey;

    switch (challenge.status) {
      case ChallengeStatus.recruiting:
        timeRemaining = challenge.timeUntilSubmission;
        timeText = tr('il_afd69ba5ce');
        timeColor = Colors.orange;
        break;
      case ChallengeStatus.submission:
        timeRemaining = challenge.timeUntilVoting;
        timeText = tr('il_8b1fdff570');
        timeColor = Colors.blue;
        break;
      case ChallengeStatus.voting:
        timeRemaining = challenge.timeUntilEnd;
        timeText = tr('il_3dffee23bf');
        timeColor = Colors.green;
        break;
      case ChallengeStatus.completed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            tr('il_22a970d2e5'),
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }

    if (timeRemaining.isNegative) {
      timeText = tr('il_22a970d2e5');
      timeColor = Colors.red;
    } else {
      if (timeRemaining.inDays > 0) {
        timeText = '${timeRemaining.inDays} ${tr('il_18ac3e7343')}';
      } else if (timeRemaining.inHours > 0) {
        timeText = '${timeRemaining.inHours} ${tr('il_aaa9402664')}';
      } else if (timeRemaining.inMinutes > 0) {
        timeText = '${timeRemaining.inMinutes} ${tr('il_1f6fa6f69d')}';
      } else {
        timeText = tr('il_5a2f1ea47f');
        timeColor = Colors.red;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: timeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: timeColor.withOpacity(0.3)),
      ),
      child: Text(
        timeText,
        style: TextStyle(
          color: timeColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Stream<List<Challenge>> _getFilteredChallengesStream() {
    Stream<List<Challenge>> stream = _challengesRepo.getActiveChallenges();

    // Filter by status
    if (_selectedStatus != 'all') {
      final status = ChallengeStatus.values.firstWhere(
        (s) => s.toString().split('.').last == _selectedStatus,
        orElse: () => ChallengeStatus.recruiting,
      );
      stream = _challengesRepo.getChallengesByStatus(status);
    }

    // Filter by type
    if (_selectedType != 'all') {
      final type = parseChallengeType(_selectedType);
      stream = _challengesRepo.getChallengesByType(type);
    }

    // Filter by city
    if (_selectedCity.isNotEmpty) {
      stream = _challengesRepo.getChallengesByCity(_selectedCity);
    }

    return stream.map((challenges) {
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        return challenges.where((challenge) {
          final query = _searchQuery.toLowerCase();
          return challenge.title.toLowerCase().contains(query) ||
              challenge.description.toLowerCase().contains(query) ||
              challenge.creatorName.toLowerCase().contains(query) ||
              challenge.city.toLowerCase().contains(query);
        }).toList();
      }
      return challenges;
    });
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'all':
        return tr('il_8ee57323a6');
      case 'recruiting':
        return tr('il_a0d55310f8');
      case 'submission':
        return tr('il_fefdc339a9');
      case 'voting':
        return tr('il_aca2f665db');
      case 'completed':
        return tr('il_22a970d2e5');
      default:
        return status;
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'all':
        return tr('il_f10988e79e');
      case 'goal':
        return tr('il_cdbf6975e8');
      case 'shot_power':
        return tr('il_a387ab1835');
      case 'save':
        return tr('il_1509f561f2');
      case 'pass':
        return tr('il_ebdf8cc00b');
      case 'long_pass':
        return tr('il_a30ef79268');
      case 'tackle':
        return tr('il_9c0dd00951');
      case 'dribbling':
        return tr('il_0b337d1bc7');
      case 'penalty':
        return tr('il_241c754092');
      case 'wall':
        return tr('il_93819c7151');
      case 'strategy':
        return tr('il_6b27710dfa');
      case 'trick':
        return tr('il_209e3aa0b5');
      case 'other':
        return tr('il_f97e9da0e3');
      default:
        return type;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${tr('il_738bb7160d')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${tr('il_9e9470fd83')}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${tr('il_f47b946b9b')}';
    } else {
      return tr('il_66f53417d3');
    }
  }

  void _showCreateChallenge() {
    context.router.push(ChallengeCreateRoute());
  }

  void _openChallengeDetails(Challenge challenge) {
    context.router.push(ChallengeDetailsRoute(challenge: challenge));
  }
}
