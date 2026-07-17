import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/chat/chat_bloc.dart';
import '../../../blocs/session/session_bloc.dart';
import '../../shared/platform_loader.dart';
import '../../shared/covaone_theme.dart';

/// Bottom-of-chat form that collects email + name before the first message.
/// Animates out (fade + height collapse) when [SessionLoaded] with profile.
class LeadCaptureForm extends StatefulWidget {
  const LeadCaptureForm({super.key});

  @override
  State<LeadCaptureForm> createState() => _LeadCaptureFormState();
}

class _LeadCaptureFormState extends State<LeadCaptureForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  late final AnimationController _animCtrl;
  late final Animation<double> _heightFactor;
  late final Animation<double> _opacity;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, // fully expanded on mount
    );
    _heightFactor = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _opacity = Tween<double>(begin: 0, end: 1).animate(_animCtrl);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(Color themeColor) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    context.read<SessionBloc>().add(SetProfileEvent(
          email: _emailCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
        ));
  }

  void _collapseAndConnect(String sessionId) {
    _animCtrl.reverse().then((_) {
      if (mounted) {
        context.read<ChatBloc>().add(SocketConnectEvent(sessionId: sessionId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SessionBloc, SessionState>(
      listenWhen: (prev, curr) =>
          prev is! SessionLoaded && curr is SessionLoaded ||
          (curr is SessionProfileFormVisible && curr.profileError != null),
      listener: (context, state) {
        if (state is SessionLoaded) {
          _collapseAndConnect(state.session.sessionId);
          setState(() => _submitting = false);
        } else if (state is SessionProfileFormVisible &&
            state.profileError != null) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.profileError!)),
          );
        }
      },
      builder: (context, sessionState) {
        final themeColor = sessionState.themeColor;

        return SizeTransition(
          sizeFactor: _heightFactor,
          axisAlignment: -1,
          child: FadeTransition(
            opacity: _opacity,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 12),
                    Text('Hey There 👋, Let us know you',
                        style: CovaoneTheme.subheadStyle()),
                    const SizedBox(height: 4),
                    Text(
                        'Please give us some information so we can better assist you.',
                        style: CovaoneTheme.captionStyle()),
                    const SizedBox(height: 12),

                    // Email field
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: CovaoneTheme.bodyStyle(),
                      decoration: _inputDecoration('Email Address', themeColor),
                      validator: (v) {
                        if (v == null || !v.contains('@') || !v.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Name field
                    TextFormField(
                      controller: _nameCtrl,
                      style: CovaoneTheme.bodyStyle(),
                      decoration: _inputDecoration('Full Name', themeColor),
                      validator: (v) {
                        if (v == null || v.trim().length < 4) {
                          return 'Name must be at least 4 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _submitting ? null : () => _submit(themeColor),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _submitting
                            ? const PlatformLoader(
                                color: Colors.white,
                                strokeWidth: 2,
                                size: 18,
                              )
                            : Text('Start Conversation',
                                style:
                                    CovaoneTheme.bodyStyle(color: Colors.white)
                                        .copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint, Color themeColor) =>
      InputDecoration(
        hintText: hint,
        hintStyle: CovaoneTheme.captionStyle(),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: themeColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
      );
}
