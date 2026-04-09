import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/features/challenges/data/challenge_service.dart';
import 'challenge_create_screen.dart';
import 'challenge_details_screen.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/widgets/player_avatar_button.dart';

@RoutePage()
class ChallengeListScreen extends StatefulWidget {
  @override
  _ChallengeListScreenState createState() => _ChallengeListScreenState();
}

class _ChallengeListScreenState extends State<ChallengeListScreen> {
  final ChallengeService _challengeService = ChallengeService();
  
  String _selectedStatus = 'all';
  String _selectedType = 'all';
  String _selectedCity = '';
  String _searchQuery = '';

  final List<String> _statuses = [
    'all',
    'recruiting',
    'submission', 
    'voting',
    'completed'
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
    I18n.t('all_cities'),
    I18n.t('kyiv'),
    I18n.t('kharkiv'),
    I18n.t('odesa'),
    I18n.t('dnipro'),
    I18n.t('lviv'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e7d32),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          I18n.inline('🏆 Челенджі', '🏆 Challenges'),
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
            // Фільтри
            _buildFilters(),
            
            // Список челенджів
            Expanded(
              child: _buildChallengesList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateChallenge(),
        backgroundColor: const Color(0xFFFF9800),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: I18n.inline('Створити челендж', 'Create challenge'),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Пошук
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
                hintText: I18n.inline('🔍 Пошук челенджів...', '🔍 Search challenges...'),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                suffixIcon: Icon(Icons.search, color: Colors.grey[600]),
              ),
            ),
          ),
          
          const SizedBox(height: 15),
          
          // Фільтри в ряд
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
          
          // Фільтр по місту
          _buildFilterDropdown(
            _cities,
            _cities.map((c) => c == I18n.t('all_cities') ? '' : c).toList(),
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
              Expanded(child: Text(I18n.t('all'))),
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
              I18n.inline('Помилка завантаження: ${snapshot.error}', 'Error loading: ${snapshot.error}'),
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
                  I18n.inline('Поки що немає челенджів', 'No challenges yet'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  I18n.inline('Створіть перший челендж!', 'Create the first challenge!'),
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
                    I18n.inline('Створити челендж', 'Create challenge'),
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
                // Заголовок та тип
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                
                // Опис
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
                
                // Статистика
                Row(
                  children: [
                    _buildStatItem('👥', '${challenge.currentParticipants}/${challenge.maxParticipants}'),
                    const SizedBox(width: 20),
                    _buildStatItem('🎬', '${challenge.submissions.length}'),
                    const SizedBox(width: 20),
                    _buildStatItem('💰', '${challenge.prizePool.toInt()} ${I18n.inline('монет', 'coins')}'),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Аудиторія та ставка
                Row(
                  children: [
                    _buildStatItem(challenge.audienceIcon, challenge.audienceText),
                    const SizedBox(width: 20),
                    _buildStatItem('💸', '${I18n.inline('Вхід:', 'Entry:')} ${challenge.entryFee} ${I18n.inline('монет', 'coins')}'),
                    const SizedBox(width: 20),
                    _buildStatItem('⏰', '${challenge.duration} ${I18n.inline('дн.', 'days')}'),
                  ],
                ),
                
                const SizedBox(height: 15),
                
                // Прогрес бар
                _buildProgressBar(challenge),
                
                const SizedBox(height: 15),
                
                // Інформація про створювача та час
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
        progressText = I18n.inline('Збір учасників', 'Recruiting');
        break;
      case ChallengeStatus.submission:
        progress = challenge.submissionProgress;
        progressText = I18n.inline('Подання відео', 'Video submission');
        break;
      case ChallengeStatus.voting:
        progress = challenge.votingProgress;
        progressText = I18n.inline('Голосування', 'Voting');
        break;
      case ChallengeStatus.completed:
        progress = 1.0;
        progressText = I18n.inline('Завершено', 'Completed');
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
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
        timeText = I18n.inline('До подання відео', 'Until video submission');
        timeColor = Colors.orange;
        break;
      case ChallengeStatus.submission:
        timeRemaining = challenge.timeUntilVoting;
        timeText = I18n.inline('До голосування', 'Until voting');
        timeColor = Colors.blue;
        break;
      case ChallengeStatus.voting:
        timeRemaining = challenge.timeUntilEnd;
        timeText = I18n.inline('До завершення', 'Until completion');
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
            I18n.inline('Завершено', 'Completed'),
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }

    if (timeRemaining.isNegative) {
      timeText = I18n.inline('Завершено', 'Completed');
      timeColor = Colors.red;
    } else {
      if (timeRemaining.inDays > 0) {
        timeText = '${timeRemaining.inDays} ${I18n.inline('дн.', 'd')}';
      } else if (timeRemaining.inHours > 0) {
        timeText = '${timeRemaining.inHours} ${I18n.inline('год.', 'h')}';
      } else if (timeRemaining.inMinutes > 0) {
        timeText = '${timeRemaining.inMinutes} ${I18n.inline('хв.', 'min')}';
      } else {
        timeText = I18n.inline('Майже час!', 'Almost time!');
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
    Stream<List<Challenge>> stream = _challengeService.getActiveChallenges();

    // Фільтр по статусу
    if (_selectedStatus != 'all') {
      final status = ChallengeStatus.values.firstWhere(
        (s) => s.toString().split('.').last == _selectedStatus,
        orElse: () => ChallengeStatus.recruiting,
      );
      stream = _challengeService.getChallengesByStatus(status);
    }

    // Фільтр по типу
    if (_selectedType != 'all') {
      final type = parseChallengeType(_selectedType);
      stream = _challengeService.getChallengesByType(type);
    }

    // Фільтр по місту
    if (_selectedCity.isNotEmpty) {
      stream = _challengeService.getChallengesByCity(_selectedCity);
    }

    return stream.map((challenges) {
      // Фільтр по пошуковому запиту
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
        return I18n.inline('Всі статуси', 'All statuses');
      case 'recruiting':
        return I18n.inline('Збір учасників', 'Recruiting');
      case 'submission':
        return I18n.inline('Подання відео', 'Video submission');
      case 'voting':
        return I18n.inline('Голосування', 'Voting');
      case 'completed':
        return I18n.inline('Завершено', 'Completed');
      default:
        return status;
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'all':
        return I18n.inline('Всі типи', 'All types');
      case 'goal':
        return I18n.inline('Гол', 'Goal');
      case 'shot_power':
        return I18n.inline('Сила удару', 'Shot power');
      case 'save':
        return I18n.inline('Сейв', 'Save');
      case 'pass':
        return I18n.inline('Пас', 'Pass');
      case 'long_pass':
        return I18n.inline('Довгий пас', 'Long pass');
      case 'tackle':
        return I18n.inline('Підкат', 'Tackle');
      case 'dribbling':
        return I18n.inline('Дриблінг', 'Dribbling');
      case 'penalty':
        return I18n.inline('Пенальті', 'Penalty');
      case 'wall':
        return I18n.inline('Стіна / стандарт', 'Wall / set-piece');
      case 'strategy':
        return I18n.inline('Стратегія', 'Strategy');
      case 'trick':
        return I18n.inline('Трюк', 'Trick');
      case 'other':
        return I18n.inline('Інше', 'Other');
      default:
        return type;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} ${I18n.inline('дн. тому', 'd ago')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${I18n.inline('год. тому', 'h ago')}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${I18n.inline('хв. тому', 'min ago')}';
    } else {
      return I18n.inline('Щойно', 'Just now');
    }
  }

  void _showCreateChallenge() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeCreateScreen(),
      ),
    );
  }

  void _openChallengeDetails(Challenge challenge) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeDetailsScreen(challenge: challenge),
      ),
    );
  }
}
