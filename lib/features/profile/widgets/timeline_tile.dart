import 'package:flutter/material.dart';
import 'package:eyevlm_app/core/theme/app_tokens.dart';

class TimelineTile extends StatelessWidget {
  final String date;
  final String title;
  final String description;
  final bool isFirst;
  final bool isLast;
  final bool isHighRisk;

  const TimelineTile({
    super.key,
    required this.date,
    required this.title,
    required this.description,
    this.isFirst = false,
    this.isLast = false,
    this.isHighRisk = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Timeline Line & Dot
          SizedBox(
            width: 50,
            child: Column(
              children: [
                // Top Line
                Expanded(
                  child: isFirst
                      ? const SizedBox()
                      : Container(width: 2, color: Colors.grey.withAlpha(50)),
                ),
                // Dot
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  height: 16,
                  width: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isHighRisk ? Colors.redAccent : AppColors.lightPrimary,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: (isHighRisk ? Colors.red : AppColors.lightPrimary).withAlpha(100),
                        blurRadius: 6,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
                // Bottom Line
                Expanded(
                  child: isLast
                      ? const SizedBox()
                      : Container(width: 2, color: Colors.grey.withAlpha(50)),
                ),
              ],
            ),
          ),
          
          // 2. Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, right: 20.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: isHighRisk 
                      ? Border.all(color: Colors.red.withAlpha(50)) 
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        Text(
                          date,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(128),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                         color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(200),
                         height: 1.4
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
