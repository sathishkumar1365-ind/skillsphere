import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import 'widgets/hero_panel.dart';
import 'widgets/login_form.dart';
import 'widgets/sky_background.dart';

/// Login screen: sky background + white card
/// (illustration panel on the left, sign-in form on the right).
class LoginPage extends StatelessWidget {
  const LoginPage({
    super.key,
    this.onSignIn,
    this.onForgotPassword,
  });

  final SignInCallback? onSignIn;
  final VoidCallback? onForgotPassword;

  static const _wideBreakpoint = 860.0;
  static const _cardMaxWidth = 1000.0;
  static const _cardHeight = 560.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _wideBreakpoint;
    final isPhone = width < 520;
    final isTiny = width < 380;

    final form = LoginForm(
      onSignIn: onSignIn,
      onForgotPassword: onForgotPassword,
    );

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SkyBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTiny ? 8 : (isPhone ? 16 : 32),
                  vertical: isTiny ? 16 : 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
                  child: Container(
                    padding: EdgeInsets.all(isTiny ? 6 : 10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A3B6A99),
                          blurRadius: 40,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: isWide
                        ? SizedBox(
                            height: _cardHeight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Expanded(flex: 10, child: HeroPanel()),
                                Expanded(
                                  flex: 11,
                                  // Scrollable so validation messages (or a
                                  // short browser window) never overflow the
                                  // fixed-height card. Centered while it fits.
                                  child: LayoutBuilder(
                                    builder: (context, c) =>
                                        SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 16),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: c.maxHeight - 32,
                                        ),
                                        child: Center(child: form),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: isTiny ? 160 : (isPhone ? 200 : 260),
                                child: const HeroPanel(),
                              ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                    isTiny ? 8 : (isPhone ? 14 : 32),
                                    isTiny ? 24 : 32,
                                    isTiny ? 8 : (isPhone ? 14 : 32),
                                    28),
                                child: Center(child: form),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}