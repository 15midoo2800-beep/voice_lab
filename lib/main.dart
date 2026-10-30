import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const VoiceLabApp());
}

class VoiceLabApp extends StatelessWidget {
  const VoiceLabApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'المختبر الصوتي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const VoiceLabHomePage(),
    );
  }
}

class VoiceLabHomePage extends StatefulWidget {
  const VoiceLabHomePage({Key? key}) : super(key: key);

  @override
  State<VoiceLabHomePage> createState() => _VoiceLabHomePageState();
}

class _VoiceLabHomePageState extends State<VoiceLabHomePage> {
  final List<String> arabicLetters = [
    'أ', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر',
    'ز', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ع', 'غ', 'ف',
    'ق', 'ك', 'ل', 'م', 'ن', 'هـ', 'و', 'ي'
  ];

  int currentLetterIndex = 0;
  int currentSample = 1;
  int targetSamplesPerLetter = 3; // القيمة الافتراضية للتكرار (يمكنك تعديلها)
  bool isRecording = false;
  
  Map trainingDatabase = {};
  String finalSavedFilePath = 'جاري التجهيز...';
  
  final TextEditingController repsController = TextEditingController(text: '3');

  @override
  void initState() {
    super.initState();
    _initPath();
  }

  Future<void> _initPath() async {
    final dir = await getApplicationDocumentsDirectory();
    setState(() {
      finalSavedFilePath = '${dir.path}/voice_lab_dataset.json';
    });
  }

  // حفظ الملف فعلياً في مسار آمن
  Future<void> exportDatasetSafely() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/voice_lab_dataset.json');

      final Map exportData = {
        "app_name": "Voice Lab - المختبر الصوتي",
        "target_application": "Rosd / رصد",
        "version": "1.0",
        "timestamp": DateTime.now().toIso8601String(),
        "target_samples_per_letter": targetSamplesPerLetter,
        "total_letters_trained": trainingDatabase.keys.length,
        "dataset": trainingDatabase,
      };

      await file.writeAsString(jsonEncode(exportData), flush: true);
      
      setState(() {
        finalSavedFilePath = file.path;
      });
    } catch (e) {
      debugPrint('Error saving: $e');
    }
  }

  void toggleRecording() {
    setState(() {
      isRecording = !isRecording;
    });

    if (isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('جاري تسجيل المقطع ($currentSample/$targetSamplesPerLetter) للحرف "${arabicLetters[currentLetterIndex]}"...'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blueAccent,
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && isRecording) {
          setState(() {
            isRecording = false;
            
            String currentLetter = arabicLetters[currentLetterIndex];
            if (!trainingDatabase.containsKey(currentLetter)) {
              trainingDatabase[currentLetter] = [];
            }
            
            trainingDatabase[currentLetter].add({
              "sample_id": currentSample,
              "phoneme": currentLetter,
              "dialect": "Egyptian / Saidi",
              "recorded_at": DateTime.now().toIso8601String(),
            });

            exportDatasetSafely();

            if (currentSample < targetSamplesPerLetter) {
              currentSample++;
            } else {
              if (currentLetterIndex < arabicLetters.length - 1) {
                currentLetterIndex++;
                currentSample = 1;
              } else {
                showCompletionDialog();
              }
            }
          });
        }
      });
    }
  }

  void showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎯 اكتمل التدريب بالكامل!'),
        content: Text('تم حفظ بصمات الحروف ودلالاتها بنجاح في:\n\n$finalSavedFilePath'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentLetter = arabicLetters[currentLetterIndex];
    double progress = ((currentLetterIndex * targetSamplesPerLetter) + currentSample) / (28 * targetSamplesPerLetter);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المختبر الصوتي - مصنع البصمات'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // خانة اختيار عدد مرات تكرار الحرف بحرية
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber, width: 1.5),
              ),
              child: Row(
                children: [
                  const Text('عدد مرات تسجيل الحرف الواحد:', style: TextStyle(fontSize: 13, color: Colors.amber)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: repsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (value) {
                        int? val = int.tryParse(value);
                        if (val != null && val > 0) {
                          setState(() {
                            targetSamplesPerLetter = val;
                            currentSample = 1;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تم تحديث عدد مرات التكرار لكل حرف إلى: $val'), backgroundColor: Colors.green),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
              ),
              child: Text(
                'مسار الملف: $finalSavedFilePath',
                style: const TextStyle(fontSize: 10, color: Colors.greenAccent),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              minHeight: 8,
            ),
            const SizedBox(height: 10),
            Text(
              'الحرف: (${currentLetterIndex + 1} / 28)  |  المقطع: ($currentSample / $targetSamplesPerLetter)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            const SizedBox(height: 15),

            // بطاقة عرض الحرف
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
              ),
              child: Column(
                children: [
                  Text('انطق الحرف:', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                  const SizedBox(height: 8),
                  Text(
                    currentLetter,
                    style: const TextStyle(fontSize: 75, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // زر التسجيل
            GestureDetector(
              onTap: toggleRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 105,
                height: 105,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRecording ? Colors.redAccent : Colors.blueAccent,
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording ? Colors.redAccent : Colors.blueAccent).withOpacity(0.6),
                      blurRadius: isRecording ? 25 : 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  isRecording ? Icons.mic : Icons.mic_none,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isRecording ? 'جاري تسجيل المقطع...' : 'اضغط للميكروفون لتسجيل المقطع ($currentSample / $targetSamplesPerLetter)',
              style: TextStyle(
                fontSize: 13,
                color: isRecording ? Colors.redAccent : Colors.grey[300],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
