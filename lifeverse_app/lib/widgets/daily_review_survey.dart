import 'package:flutter/material.dart';
import '../theme/lifeverse_theme.dart';

class DailyReviewSurvey extends StatefulWidget {
  final List<String> questions;
  final Function(List<Map<String, String>>) onComplete;

  const DailyReviewSurvey({
    super.key, 
    required this.questions, 
    required this.onComplete,
  });

  @override
  State<DailyReviewSurvey> createState() => _DailyReviewSurveyState();
}

class _DailyReviewSurveyState extends State<DailyReviewSurvey> with SingleTickerProviderStateMixin {
  int _currentQuestionIndex = 0;
  bool _isFinished = false;
  final TextEditingController _textController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final List<Map<String, String>> _answers = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _submitAnswer() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _answers.add({
        "question": widget.questions[_currentQuestionIndex],
        "answer": text,
      });
      _textController.clear();
      
      if (_currentQuestionIndex < widget.questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        // Show thank you screen
        _isFinished = true;
      }
    });
  }

  void _finishSurvey() {
    widget.onComplete(_answers);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          color: LifeVerseColors.canvas.withValues(alpha: .96),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                child: _isFinished ? _buildThankYouScreen() : _buildQuestionScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThankYouScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline, color: LifeVerseColors.secondary, size: 64),
        const SizedBox(height: 30),
        const Text(
          "Thanks for answering my questions!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        const Text(
          "This will definitely help me know more about you and tailor your future developments.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 50),
        ElevatedButton(
          onPressed: _finishSurvey,
          style: ElevatedButton.styleFrom(
            backgroundColor: LifeVerseColors.primary,
            foregroundColor: LifeVerseColors.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text("Finish", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildQuestionScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "I want to know more about you, so please answer these honest questions for me.",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontStyle: FontStyle.italic,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          decoration: BoxDecoration(
          color: LifeVerseColors.primary.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "Question ${_currentQuestionIndex + 1}/${widget.questions.length}",
            style: const TextStyle(color: LifeVerseColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.questions[_currentQuestionIndex],
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.3),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _textController,
          maxLines: 5,
          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
          decoration: InputDecoration(
            hintText: "Type your honest answer here...",
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: LifeVerseColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: LifeVerseColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: LifeVerseColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: LifeVerseColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(25),
          ),
        ),
        const SizedBox(height: 30),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _submitAnswer,
            style: ElevatedButton.styleFrom(
              backgroundColor: LifeVerseColors.primary,
              foregroundColor: LifeVerseColors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: const Text("Next", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
