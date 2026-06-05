// ============================================================================
//  home_screen.dart
//
//  The single-screen UI:
//    ┌───────────────────────────────┐
//    │  AppBar (logo + cart badge)   │
//    │  ───────────────────────────  │
//    │  Menu Item Grid (scrollable)  │
//    │  ···  food cards  ···         │
//    │                               │
//    │     [🎙 FAB + pulse ring]     │
//    └───────────────────────────────┘
//    Drawer: Activity Log (raw JSON)
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cart_model.dart';
import 'voice_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  late final CartModel _cart;
  late final VoiceController _voice;

  // Pulse animation controller for the FAB ring
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    _cart = CartModel();
    _voice = VoiceController(_cart);

    // Looping pulse animation — only visible when recording
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rebuild UI when cart or voice state changes
    _cart.addListener(_onStateChanged);
    _voice.addListener(_onStateChanged);
  }

  void _onStateChanged() => setState(() {});

  @override
  void dispose() {
    _cart.removeListener(_onStateChanged);
    _voice.removeListener(_onStateChanged);
    _cart.dispose();
    _voice.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF121212),

      // ── AppBar ──────────────────────────────────────────────────────────
      appBar: _buildAppBar(),

      // ── Drawer: Activity Log ─────────────────────────────────────────────
      endDrawer: _buildActivityLogDrawer(),

      // ── Body ─────────────────────────────────────────────────────────────
      body: Column(
        children: [
          // Status Banner (shows transcript / errors / processing state)
          _VoiceStatusBanner(voice: _voice),

          // Scrollable food grid
          Expanded(
            child: _MenuGrid(cart: _cart),
          ),

          // Cart summary strip at the bottom
          if (_cart.totalItems > 0) _CartSummaryStrip(cart: _cart),

          // Extra padding so the FAB doesn't overlap the last row
          const SizedBox(height: 90),
        ],
      ),

      // ── FAB: Microphone Button ───────────────────────────────────────────
      floatingActionButton: _buildMicFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Text(
            '🍽️ ',
            style: GoogleFonts.baloo2(fontSize: 22),
          ),
          Text(
            'Sarvam Eats',
            style: GoogleFonts.baloo2(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFF6D3F),
            ),
          ),
        ],
      ),
      actions: [
        // Cart item count badge
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined,
                  color: Color(0xFFFF6D3F)),
              onPressed: () {},
            ),
            if (_cart.totalItems > 0)
              Positioned(
                right: 6,
                top: 6,
                child: _Badge(count: _cart.totalItems),
              ),
          ],
        ),
        // Open Activity Log drawer
        IconButton(
          icon: const Icon(Icons.terminal, color: Color(0xFF888888)),
          tooltip: 'Activity Log',
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Mic FAB ────────────────────────────────────────────────────────────────

  Widget _buildMicFAB() {
    final isRecording = _voice.state == RecordingState.recording;
    final isProcessing = _voice.state == RecordingState.processing;

    return GestureDetector(
      onTap: isProcessing ? null : _voice.toggleRecording,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring — visible only when recording
              if (isRecording)
                Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF6D3F).withOpacity(0.25),
                    ),
                  ),
                ),

              // Second pulse ring (offset timing)
              if (isRecording)
                Transform.scale(
                  scale: _pulseAnimation.value * 0.85,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF6D3F).withOpacity(0.15),
                    ),
                  ),
                ),

              // Main FAB button
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isRecording
                        ? [const Color(0xFFFF1744), const Color(0xFFFF6D3F)]
                        : isProcessing
                            ? [const Color(0xFF555555), const Color(0xFF333333)]
                            : [const Color(0xFFFF6D3F), const Color(0xFFFFBE0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording
                              ? const Color(0xFFFF1744)
                              : const Color(0xFFFF6D3F))
                          .withOpacity(0.5),
                      blurRadius: isRecording ? 24 : 12,
                      spreadRadius: isRecording ? 4 : 1,
                    ),
                  ],
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Activity Log Drawer ────────────────────────────────────────────────────

  Widget _buildActivityLogDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0D0D0D),
      width: MediaQuery.of(context).size.width * 0.88,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.terminal,
                      color: Color(0xFF4CAF50), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Activity Log',
                    style: GoogleFonts.sourceCodePro(
                      color: const Color(0xFF4CAF50),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_cart.activityLog.length} entries',
                    style: GoogleFonts.sourceCodePro(
                      color: const Color(0xFF555555),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF222222), height: 1),

            // Log entries
            Expanded(
              child: _cart.activityLog.isEmpty
                  ? Center(
                      child: Text(
                        'No API calls yet.\nTap 🎙 to place your first order.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sourceCodePro(
                          color: const Color(0xFF444444),
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _cart.activityLog.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Color(0xFF1E1E1E), height: 16),
                      itemBuilder: (context, index) {
                        final entry = _cart.activityLog[index];
                        return _LogEntry(entry: entry, index: index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets (kept in same file for brevity; split into widgets/ in prod)
// ─────────────────────────────────────────────────────────────────────────────

// ── Voice Status Banner ──────────────────────────────────────────────────────

class _VoiceStatusBanner extends StatelessWidget {
  final VoiceController voice;
  const _VoiceStatusBanner({required this.voice});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (voice.state) {
      case RecordingState.recording:
        bg = const Color(0xFF1A0000);
        fg = const Color(0xFFFF5252);
        icon = Icons.graphic_eq;
        break;
      case RecordingState.processing:
        bg = const Color(0xFF0A1220);
        fg = const Color(0xFF64B5F6);
        icon = Icons.cloud_upload_outlined;
        break;
      case RecordingState.success:
        bg = const Color(0xFF0A1A0A);
        fg = const Color(0xFF69F0AE);
        icon = Icons.check_circle_outline;
        break;
      case RecordingState.error:
        bg = const Color(0xFF1A0A00);
        fg = const Color(0xFFFFAB40);
        icon = Icons.error_outline;
        break;
      default:
        bg = const Color(0xFF1A1A1A);
        fg = const Color(0xFF888888);
        icon = Icons.mic_none_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              voice.state == RecordingState.error
                  ? (voice.errorMessage ?? voice.statusMessage)
                  : voice.statusMessage,
              style: GoogleFonts.sourceCodePro(
                color: fg,
                fontSize: 12,
                fontStyle: voice.state == RecordingState.success
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Menu Grid ─────────────────────────────────────────────────────────────────

class _MenuGrid extends StatelessWidget {
  final CartModel cart;
  const _MenuGrid({required this.cart});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: kMenuItems.length,
      itemBuilder: (context, index) {
        final item = kMenuItems[index];
        return _MenuCard(item: item, cart: cart);
      },
    );
  }
}

// ── Menu Card ─────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final MenuItem item;
  final CartModel cart;

  const _MenuCard({required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    final qty = cart.quantityOf(item.id);
    final inCart = qty > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1C1C1E),
        border: inCart
            ? Border.all(color: item.accentColor, width: 1.5)
            : Border.all(color: const Color(0xFF2C2C2E), width: 1),
        boxShadow: inCart
            ? [
                BoxShadow(
                  color: item.accentColor.withOpacity(0.20),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Emoji + quantity badge ─────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Gradient background panel
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    gradient: LinearGradient(
                      colors: [
                        item.accentColor.withOpacity(0.15),
                        item.accentColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(item.emoji,
                        style: const TextStyle(fontSize: 52)),
                  ),
                ),
                // Quantity badge (top-right)
                if (inCart)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _Badge(count: qty, color: item.accentColor),
                  ),
              ],
            ),
          ),

          // ── Text + controls ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${item.priceINR.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: item.accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                // +/- stepper
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StepperButton(
                      icon: Icons.remove,
                      onTap: qty > 0
                          ? () => cart.adjustQuantity(item.id, -1)
                          : null,
                      color: item.accentColor,
                    ),
                    Text(
                      '$qty',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: inCart ? item.accentColor : Colors.white38,
                      ),
                    ),
                    _StepperButton(
                      icon: Icons.add,
                      onTap: () => cart.adjustQuantity(item.id, 1),
                      color: item.accentColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stepper Button ─────────────────────────────────────────────────────────────

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap != null
              ? color.withOpacity(0.15)
              : Colors.transparent,
          border: Border.all(
            color: onTap != null ? color : Colors.white10,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: onTap != null ? color : Colors.white24,
        ),
      ),
    );
  }
}

// ── Cart Summary Strip ─────────────────────────────────────────────────────────

class _CartSummaryStrip extends StatelessWidget {
  final CartModel cart;
  const _CartSummaryStrip({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6D3F),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6D3F).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Text(
            '${cart.totalItems} item${cart.totalItems > 1 ? 's' : ''}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            '₹${cart.totalPrice.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Checkout →',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge ──────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  final Color color;

  const _Badge({
    required this.count,
    this.color = const Color(0xFFFF6D3F),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: count > 0 ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 6,
            )
          ],
        ),
        child: Text(
          '$count',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── Log Entry ──────────────────────────────────────────────────────────────────

class _LogEntry extends StatefulWidget {
  final Map<String, dynamic> entry;
  final int index;

  const _LogEntry({required this.entry, required this.index});

  @override
  State<_LogEntry> createState() => _LogEntryState();
}

class _LogEntryState extends State<_LogEntry> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = widget.entry['response']?['success'] == true;
    final bool isError = widget.entry['error'] != null;
    final Color statusColor =
        isError ? const Color(0xFFFFAB40) : (isSuccess ? const Color(0xFF69F0AE) : const Color(0xFFFF5252));
    final String statusLabel =
        isError ? 'LOCAL ERROR' : (isSuccess ? 'SUCCESS' : 'API ERROR');

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.sourceCodePro(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.entry['timestamp'] ?? '',
                  style: GoogleFonts.sourceCodePro(
                    color: const Color(0xFF444444),
                    fontSize: 9,
                  ),
                ),
              ),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: const Color(0xFF444444),
                size: 16,
              ),
            ],
          ),

          // Transcript preview
          if (!isError && widget.entry['response'] != null) ...[
            const SizedBox(height: 4),
            Text(
              '"${widget.entry['response']['raw_transcript'] ?? ''}"',
              style: GoogleFonts.sourceCodePro(
                color: const Color(0xFF888888),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Full JSON dump (expandable)
          if (_expanded) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFF1E1E1E), width: 1),
              ),
              child: SelectableText(
                const JsonEncoder.withIndent('  ')
                    .convert(widget.entry),
                style: GoogleFonts.sourceCodePro(
                  color: const Color(0xFF66BB6A),
                  fontSize: 9.5,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
