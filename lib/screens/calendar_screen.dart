import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// Event class to store event details
class Event {
  final String title;
  final String category;
  final String description;
  bool isCompleted;

  Event({
    required this.title,
    required this.category,
    required this.description,
    this.isCompleted = false,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Event>> events = {};

  List<Event> _getEventsForDay(DateTime day) {
    return events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void _toggleEventCompletion(DateTime day, int eventIndex) {
    setState(() {
      final eventDay = DateTime(day.year, day.month, day.day);
      if (events[eventDay] != null && events[eventDay]!.length > eventIndex) {
        events[eventDay]![eventIndex].isCompleted =
            !events[eventDay]![eventIndex].isCompleted;
      }
    });
  }

  void _showAddEventDialog() {
    String selectedCategory = 'exercise';
    String title = '';
    String description = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Event Title'),
                  onChanged: (value) {
                    title = value;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: '카테고리'),
                  items: const [
                    DropdownMenuItem(value: 'exercise', child: Text('운동')),
                    DropdownMenuItem(value: 'medicine', child: Text('약먹기')),
                  ],
                  onChanged: (value) {
                    selectedCategory = value!;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  onChanged: (value) {
                    description = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (title.isNotEmpty) {
                  setState(() {
                    final event = Event(
                      title: title,
                      category: selectedCategory,
                      description: description,
                    );

                    final eventDay = DateTime(
                      _selectedDay.year,
                      _selectedDay.month,
                      _selectedDay.day,
                    );

                    if (events[eventDay] == null) {
                      events[eventDay] = [];
                    }
                    events[eventDay]!.add(event);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Screen'),
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: "ko_KR",
            focusedDay: _focusedDay,
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay ?? _focusedDay;
              });
            },
            eventLoader: _getEventsForDay,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _getEventsForDay(_selectedDay).length,
              itemBuilder: (context, index) {
                final event = _getEventsForDay(_selectedDay)[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: InkWell(
                    onTap: () => _toggleEventCompletion(_selectedDay, index),
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: event.isCompleted,
                            onChanged: (_) =>
                                _toggleEventCompletion(_selectedDay, index),
                          ),
                          Icon(
                            event.category == 'exercise'
                                ? Icons.fitness_center
                                : Icons.medication,
                            color: event.category == 'exercise'
                                ? const Color(0xFF3DDAA8)
                                : const Color(0xFF7F46E3),
                          ),
                        ],
                      ),
                      title: Text(
                        event.title,
                        style: TextStyle(
                          decoration: event.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        event.description,
                        style: TextStyle(
                          decoration: event.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
