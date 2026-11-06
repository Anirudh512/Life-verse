import 'package:flutter/material.dart';
import '../theme/lifeverse_theme.dart';

class HDEGrowthContractScreen extends StatefulWidget {
  const HDEGrowthContractScreen({super.key});

  @override
  State<HDEGrowthContractScreen> createState() => _HDEGrowthContractScreenState();
}

class _HDEGrowthContractScreenState extends State<HDEGrowthContractScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeVerseColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Growth Contract",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "LifeVerse is not a game.\n\nThis journey is designed to help you develop as a person.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              _buildRule("Consistency matters more than perfection."),
              _buildRule("Returning after a break is part of growth."),
              _buildRule("Your score reflects recorded activity over time."),
              _buildRule("Growth takes time."),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: LifeVerseColors.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: LifeVerseColors.line),
                ),
                child: const Text(
                  "\"You are competing with yesterday's version of yourself—not with anyone else.\"",
                  style: TextStyle(
                    color: LifeVerseColors.muted,
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              CheckboxListTile(
                value: _agreed,
                activeColor: LifeVerseColors.primary,
                onChanged: (val) {
                  setState(() {
                    _agreed = val ?? false;
                  });
                },
                title: const Text(
                  "I understand and want to begin my development journey.",
                  style: TextStyle(color: Colors.white),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _agreed
                      ? () {
                          // Proceed to the Pillar Dashboard
                          Navigator.pushReplacementNamed(context, '/hde_dashboard');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LifeVerseColors.primary,
                    foregroundColor: LifeVerseColors.onPrimary,
                    disabledBackgroundColor: LifeVerseColors.line,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "I Commit",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LifeVerseColors.onPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: LifeVerseColors.primary, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
