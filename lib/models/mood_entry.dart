import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MoodAnalysisData {
  final String id;
  final int moodIndex;
  final DateTime date;
  final String category;
  final String description;

  MoodAnalysisData({
    required this.id,
    required this.moodIndex,
    required this.date,
    required this.category,
    required this.description,
  });

  factory MoodAnalysisData.fromFirestore(String id, Map<String, dynamic> data) {
    return MoodAnalysisData(
      id: id,
      moodIndex: data['moodIndex'] ?? 0,
      date: (data['date'] as Timestamp).toDate(),
      category: data['category'] ?? 'General',
      description: data['description'] ?? '',
    );
  }
}

class MoodStats {
  final int moodIndex;
  final String label;
  final String emoji;
  final int count;
  final double percentage;

  MoodStats({
    required this.moodIndex,
    required this.label,
    required this.emoji,
    required this.count,
    required this.percentage,
  });
}

class CategoryStats {
  final String category;
  final double averageScore;
  final String averageLabel;
  final String averageEmoji;
  final int count;

  CategoryStats({
    required this.category,
    required this.averageScore,
    required this.averageLabel,
    required this.averageEmoji,
    required this.count,
  });
}

class MoodAnalyzer {
  static const List<String> moodLabels = ['Angry', 'Sad', 'Neutral', 'Happy', 'Excellent'];
  static const List<String> moodEmojis = ['😠', '😔', '🙂', '😄', '😊'];
  static const List<Color> moodColors = [
    Color(0xFFEF5350), // Red - Angry
    Color(0xFFFF9800), // Orange - Sad  
    Color(0xFF8BC34A), // Light Green - Neutral
    Color(0xFF2196F3), // Blue - Happy
    Color(0xFF9C27B0), // Purple - Excellent
  ];

  static List<MoodAnalysisData> filterByDateRange(
    List<MoodAnalysisData> data,
    DateTime startDate,
    DateTime endDate,
  ) {
    return data.where((mood) {
      return mood.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
             mood.date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  static MoodStats? getMostCommonMood(List<MoodAnalysisData> data) {
    if (data.isEmpty) return null;

    Map<int, int> moodCounts = {};
    for (var mood in data) {
      moodCounts[mood.moodIndex] = (moodCounts[mood.moodIndex] ?? 0) + 1;
    }

    var mostCommon = moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    
    return MoodStats(
      moodIndex: mostCommon.key,
      label: moodLabels[mostCommon.key],
      emoji: moodEmojis[mostCommon.key],
      count: mostCommon.value,
      percentage: (mostCommon.value / data.length) * 100,
    );
  }

  static List<MoodStats> getMoodDistribution(List<MoodAnalysisData> data) {
    Map<int, int> moodCounts = {};
    
    // Initialize all moods with 0
    for (int i = 0; i < 5; i++) {
      moodCounts[i] = 0;
    }

    // Count occurrences
    for (var mood in data) {
      moodCounts[mood.moodIndex] = (moodCounts[mood.moodIndex] ?? 0) + 1;
    }

    return moodCounts.entries.map((entry) {
      return MoodStats(
        moodIndex: entry.key,
        label: moodLabels[entry.key],
        emoji: moodEmojis[entry.key],
        count: entry.value,
        percentage: data.isEmpty ? 0 : (entry.value / data.length) * 100,
      );
    }).toList();
  }

  static double getAverageMoodScore(List<MoodAnalysisData> data) {
    if (data.isEmpty) return 0;
    return data.map((m) => m.moodIndex).reduce((a, b) => a + b) / data.length;
  }

  static List<CategoryStats> getCategoryAnalysis(List<MoodAnalysisData> data) {
    Map<String, List<int>> categoryMoods = {};
    
    for (var mood in data) {
      categoryMoods.putIfAbsent(mood.category, () => []).add(mood.moodIndex);
    }

    return categoryMoods.entries.map((entry) {
      double average = entry.value.reduce((a, b) => a + b) / entry.value.length;
      int roundedAverage = average.round().clamp(0, 4);
      
      return CategoryStats(
        category: entry.key,
        averageScore: average,
        averageLabel: moodLabels[roundedAverage],
        averageEmoji: moodEmojis[roundedAverage],
        count: entry.value.length,
      );
    }).toList()..sort((a, b) => b.averageScore.compareTo(a.averageScore));
  }

  static List<String> generateInsights(List<MoodAnalysisData> data) {
    List<String> insights = [];
    
    if (data.isEmpty) {
      insights.add("Start tracking your mood to see personalized insights!");
      return insights;
    }

    var mostCommon = getMostCommonMood(data);
    if (mostCommon != null) {
      insights.add("Your most common mood is ${mostCommon.label} ${mostCommon.emoji} (${mostCommon.percentage.toStringAsFixed(1)}% of the time)");
    }

    double average = getAverageMoodScore(data);
    int roundedAverage = average.round().clamp(0, 4);
    insights.add("Your average mood score is ${average.toStringAsFixed(1)}/4, which is ${moodLabels[roundedAverage]} ${moodEmojis[roundedAverage]}");

    var categoryStats = getCategoryAnalysis(data);
    if (categoryStats.isNotEmpty) {
      var best = categoryStats.first;
      var worst = categoryStats.last;
      
      insights.add("${best.category} makes you feel the best (avg: ${best.averageScore.toStringAsFixed(1)})");
      if (categoryStats.length > 1) {
        insights.add("${worst.category} tends to affect your mood more negatively (avg: ${worst.averageScore.toStringAsFixed(1)})");
      }
    }

    int positiveCount = data.where((m) => m.moodIndex >= 3).length;
    double positivePercentage = (positiveCount / data.length) * 100;
    insights.add("You felt positive (Happy/Excellent) ${positivePercentage.toStringAsFixed(1)}% of the time");

    return insights;
  }
}