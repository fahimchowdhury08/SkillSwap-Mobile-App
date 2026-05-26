
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  // ── Search controller ──────────────────────────────────────────
  final _searchController = TextEditingController();
  String _searchQuery     = '';

  // ── All FAQ data ───────────────────────────────────────────────
  final List<_FaqCategory> _categories = const [
    _FaqCategory(
      icon: '🚀',
      title: 'Getting Started',
      items: [
        _FaqItem(
          question: 'How do I create an account?',
          answer:
              'Tap "Join Now" on the Get Started screen. Enter your name, email and password. After signing up you will be taken to add your skills.',
        ),
        _FaqItem(
          question: 'How do I add my skills?',
          answer:
              'After signup you will see a skill setup screen. Type a skill you have and tap the + button. Do the same for skills you want to learn. You can also add more skills later from Personal Details in the menu.',
        ),
        _FaqItem(
          question: 'Why is my home feed empty?',
          answer:
              'Your feed shows people who teach skills you want to learn. Make sure you have added at least one learning skill. Pull down to refresh the feed.',
        ),
      ],
    ),
    _FaqCategory(
      icon: '🔄',
      title: 'Swapping & Matching',
      items: [
        _FaqItem(
          question: 'How does a skill swap work?',
          answer:
              'You send a swap request to someone. You offer to teach one of your skills in exchange for learning one of their skills. If they accept, you are matched and can start chatting and scheduling sessions.',
        ),
        _FaqItem(
          question: 'How do I send a swap request?',
          answer:
              'Tap any profile card on the home feed to open their profile. Tap the "Swap →" button. Choose which skill you will teach, review what you will learn, and tap Send Swap Proposal.',
        ),
        _FaqItem(
          question: 'What happens when my swap is accepted?',
          answer:
              'You will get a notification. A match moment screen will appear with a confetti animation. The chat is now unlocked and you can message each other and book sessions.',
        ),
        _FaqItem(
          question: 'Can I cancel a swap request?',
          answer:
              'Yes. Go to the Swap tab and open the Sent section. You can see all your sent requests and their status. If it is still pending, contact the person through another channel as direct cancellation is coming in v2.',
        ),
      ],
    ),
    _FaqCategory(
      icon: '💬',
      title: 'Chat & Video Calls',
      items: [
        _FaqItem(
          question: 'Why is the message button disabled?',
          answer:
              'Messaging is only unlocked after both users have accepted a swap. This ensures both parties are committed before starting a conversation.',
        ),
        _FaqItem(
          question: 'How do I start a video call?',
          answer:
              'Open a chat with your matched partner. Tap the video camera icon in the top right corner. You will see a pre-join screen where you can toggle your camera and mic before joining.',
        ),
        _FaqItem(
          question: 'Video call not connecting — what to do?',
          answer:
              'Make sure both devices are on the same stable WiFi or strong mobile data. Check that camera and microphone permissions are granted in your phone settings. Try closing and reopening the app.',
        ),
        _FaqItem(
          question: 'Can I share my screen during a call?',
          answer:
              'Yes. During an active video call, tap the screen share button in the Jitsi call controls at the bottom of the screen.',
        ),
      ],
    ),
    _FaqCategory(
      icon: '🌐',
      title: 'Communities',
      items: [
        _FaqItem(
          question: 'How do I create a community?',
          answer:
              'Go to Community from the hamburger menu. Tap the + button. Fill in the community name, description and skill tag. Tap Create Community. You will become the admin automatically.',
        ),
        _FaqItem(
          question: 'How do I join a community?',
          answer:
              'Browse communities and tap Join on any card. Your request will be sent to the community admin. Once approved you will get a notification and can access the community feed.',
        ),
        _FaqItem(
          question: 'How long does community approval take?',
          answer:
              'It depends on the admin. They receive a notification immediately. Most admins approve within a few hours. If it takes too long you can try finding another community.',
        ),
      ],
    ),
    _FaqCategory(
      icon: '🔒',
      title: 'Account & Safety',
      items: [
        _FaqItem(
          question: 'How do I verify my skill?',
          answer:
              'Go to Personal Details from the hamburger menu. Tap any skill chip. Upload a certificate or credential that proves your skill. Once uploaded your skill will show a verified ✓ badge.',
        ),
        _FaqItem(
          question: 'How do I report a user?',
          answer:
              'Open any user profile. Tap the three-dot ⋮ menu in the top right corner. Select a report reason. The report will be submitted immediately.',
        ),
        _FaqItem(
          question: 'How do I change my password?',
          answer:
              'Go to Settings from the hamburger menu. Tap Change Password. Enter your new password twice and tap Update Password.',
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filter categories by search query ──────────────────────────
  List<_FaqCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;

    final query = _searchQuery.toLowerCase();
    final filtered = <_FaqCategory>[];

    for (final category in _categories) {
      final matchingItems = category.items.where((item) {
        return item.question.toLowerCase().contains(query) ||
            item.answer.toLowerCase().contains(query);
      }).toList();

      if (matchingItems.isNotEmpty) {
        filtered.add(_FaqCategory(
          icon:  category.icon,
          title: category.title,
          items: matchingItems,
        ));
      }
    }

    return filtered;
  }

  // ── Launch email ───────────────────────────────────────────────
  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@skillswap.app',
      query: 'subject=SkillSwap Support Request',
    );
    try {
      await launchUrl(uri);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open email app.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCategories;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help & Support',
          style: AppTextStyles.heading2,
        ),
      ),
      body: Column(
        children: [

          // ── Search bar ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              style: AppTextStyles.bodyBold,
              onChanged: (val) =>
                  setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search FAQs...',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: 'Nunito',
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.cardSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.indigo,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // ── FAQ list ─────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No results found',
                      style: AppTextStyles.body,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    children: [

                      // FAQ categories
                      ...filtered.map(
                        (category) => _buildCategory(category),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Still need help card ─────────────
                      _buildContactCard(),

                      const SizedBox(height: AppSpacing.xl),

                    ],
                  ),
          ),

        ],
      ),
    );
  }

  // ── Category section ───────────────────────────────────────────
  Widget _buildCategory(_FaqCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const SizedBox(height: AppSpacing.lg),

        // Category header
        Row(
          children: [
            Text(
              category.icon,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              category.title,
              style: AppTextStyles.heading3,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // FAQ items
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.elevated),
          ),
          child: Column(
            children: category.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item  = entry.value;
              final isLast = index == category.items.length - 1;

              return Column(
                children: [
                  _buildFaqItem(item),
                  if (!isLast)
                    const Divider(
                      color: AppColors.elevated,
                      height: 1,
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md,
                    ),
                ],
              );
            }).toList(),
          ),
        ),

      ],
    );
  }

  // ── FAQ expansion tile ─────────────────────────────────────────
  Widget _buildFaqItem(_FaqItem item) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        title: Text(
          item.question,
          style: AppTextStyles.bodyBold,
        ),
        iconColor: AppColors.indigo,
        collapsedIconColor: AppColors.textMuted,
        children: [
          Text(
            item.answer,
            style: AppTextStyles.body.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  // ── Contact card ───────────────────────────────────────────────
  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Column(
        children: [

          const Icon(
            Icons.headset_mic_rounded,
            color: AppColors.indigo,
            size: 36,
          ),

          const SizedBox(height: AppSpacing.sm),

          const Text(
            'Still need help?',
            style: AppTextStyles.heading3,
          ),

          const SizedBox(height: AppSpacing.xs),

          const Text(
            'Our support team is ready to help you',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.lg),

          // Email support button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _launchEmail,
              icon: const Icon(Icons.email_outlined, size: 18),
              label: const Text(
                'Email Support',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}

// ── Data classes ───────────────────────────────────────────────────
class _FaqCategory {
  final String icon;
  final String title;
  final List<_FaqItem> items;

  const _FaqCategory({
    required this.icon,
    required this.title,
    required this.items,
  });
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });
}