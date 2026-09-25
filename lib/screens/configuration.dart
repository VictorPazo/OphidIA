import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../theme/app_page_route.dart';
import 'login.dart';

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});

  @override
  State<ConfigurationPage> createState() =>
      _ConfigurationPageState();
}

class _ConfigurationPageState
    extends State<ConfigurationPage> {

  final user =
      Supabase.instance.client.auth.currentUser;

  bool notificationsEnabled = true;
  bool showConfidence = true;
  bool autoFlash = false;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {

    final prefs =
    await SharedPreferences.getInstance();

    setState(() {

      notificationsEnabled =
          prefs.getBool(
            'notificationsEnabled',
          ) ??
              true;

      showConfidence =
          prefs.getBool(
            'showConfidence',
          ) ??
              true;

      autoFlash =
          prefs.getBool(
            'autoFlash',
          ) ??
              false;
    });
  }

  Future<void> saveSetting(
      String key,
      bool value,
      ) async {

    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setBool(key, value);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "preferences_saved".tr(),
        ),

        duration:
        const Duration(seconds: 2),
      ),
    );
  }

  Future<void> resetTutorial() async {

    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setBool(
      'naoMostrarTutorial',
      false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "tutorial_reset".tr(),
        ),
      ),
    );
  }

  Future<void> confirmLogout() async {

    final bool? confirmed =
    await showDialog<bool>(

      context: context,

      builder: (dialogContext) {

        return AlertDialog(

          title: Text(
            "logout_confirm_title".tr(),
          ),

          content: Text(
            "logout_confirm_text".tr(),
          ),

          actions: [

            TextButton(

              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: Text("cancel".tr()),
            ),

            ElevatedButton(

              style:
              ElevatedButton.styleFrom(

                backgroundColor:
                Colors.red,
              ),

              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              child: Text(

                "logout".tr(),

                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;

    await logout();
  }

  Future<void> logout() async {

    await Supabase.instance.client.auth
        .signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,

      AppPageRoute(
        builder: (_) => LoginPage(),
        transition: AppTransition.fade,
      ),

          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        backgroundColor: Colors.transparent,

        elevation: 0,

        centerTitle: true,

        title: Text(
          "settings".tr(),
        ),
      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(AppSpacing.lg),

        child: Column(

          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            buildSectionTitle(
              "account".tr(),
            ),

            buildCard(

              child: Column(

                children: [

                  ListTile(

                    leading:
                    const Icon(Icons.person),

                    title: Text(
                      user?.userMetadata?['nome']
                          ??
                          "user".tr(),
                    ),

                    subtitle: Text(
                      user?.email ??
                          "no_email".tr(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            buildSectionTitle(
              "preferences".tr(),
            ),

            buildCard(

              child: Column(

                children: [

                  SwitchListTile(

                    value:
                    notificationsEnabled,

                    title: Text(
                      "enable_notifications"
                          .tr(),
                    ),

                    onChanged: (value) {

                      setState(() {
                        notificationsEnabled =
                            value;
                      });

                      saveSetting(
                        'notificationsEnabled',
                        value,
                      );
                    },
                  ),

                  const Divider(),

                  ListTile(

                    leading:
                    const Icon(Icons.refresh),

                    title: Text(
                      "show_tutorial_again"
                          .tr(),
                    ),

                    onTap: resetTutorial,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            buildSectionTitle(
              "ai".tr(),
            ),

            buildCard(

              child: Column(

                children: [

                  SwitchListTile(

                    value: showConfidence,

                    title: Text(
                      "show_ai_confidence"
                          .tr(),
                    ),

                    subtitle: Text(
                      "show_accuracy_percentage"
                          .tr(),
                    ),

                    onChanged: (value) {

                      setState(() {
                        showConfidence = value;
                      });

                      saveSetting(
                        'showConfidence',
                        value,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            buildSectionTitle(
              "camera".tr(),
            ),

            buildCard(

              child: Column(

                children: [

                  SwitchListTile(

                    value: autoFlash,

                    title: Text(
                      "automatic_flash".tr(),
                    ),

                    onChanged: (value) {

                      setState(() {
                        autoFlash = value;
                      });

                      saveSetting(
                        'autoFlash',
                        value,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            buildSectionTitle(
              "about".tr(),
            ),

            buildCard(

              child: Column(

                children: const [

                  ListTile(

                    leading:
                    Icon(Icons.info_outline),

                    title:
                    Text('Snakes of IMT'),

                    subtitle:
                    Text('Version 1.0.0'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            SizedBox(

              width: double.infinity,

              child: ElevatedButton.icon(

                style:
                ElevatedButton.styleFrom(

                  backgroundColor:
                  AppColors.danger,
                ),

                onPressed: confirmLogout,

                icon: const Icon(
                  Icons.logout,
                ),

                label: Text(

                  "logout".tr(),

                  style: const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSectionTitle(String title) {

    return Padding(

      padding:
      const EdgeInsets.only(bottom: AppSpacing.sm),

      child: Text(
        title,

        style: AppTextStyles.sectionTitle,
      ),
    );
  }

  Widget buildCard({
    required Widget child,
  }) {

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(20),
      ),

      child: child,
    );
  }
}