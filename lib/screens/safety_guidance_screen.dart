import 'package:flutter/material.dart';
import '../app_colors.dart';

/// Picture-led safety prompts in English, Hindi, and Marathi for field use.
class SafetyGuidanceScreen extends StatelessWidget {
  const SafetyGuidanceScreen({super.key});

  static const _guides = <_SafetyGuide>[
    _SafetyGuide(
      Icons.local_fire_department,
      'Never burn wires or electronics',
      'तार या इलेक्ट्रॉनिक्स कभी न जलाएँ',
      'तारा किंवा इलेक्ट्रॉनिक वस्तू जाळू नका',
      'Burning releases poisonous smoke. Keep material away from flames.',
      'जलाने से जहरीला धुआँ निकलता है। आग से दूर रखें।',
      'जाळल्याने विषारी धूर निघतो. आगीपासून दूर ठेवा.',
    ),
    _SafetyGuide(
      Icons.battery_alert,
      'Keep batteries whole and dry',
      'बैटरियों को साबुत और सूखा रखें',
      'बॅटरी अखंड आणि कोरडी ठेवा',
      'Do not puncture, crush, heat, or mix damaged batteries. Isolate swollen or leaking cells.',
      'बैटरी को छेदें, कुचलें या गर्म न करें। फूली या रिसती बैटरी अलग रखें।',
      'बॅटरी टोचू, चिरडू किंवा गरम करू नका. फुगलेली किंवा गळणारी बॅटरी वेगळी ठेवा.',
    ),
    _SafetyGuide(
      Icons.monitor,
      'Do not open CRT screens',
      'CRT स्क्रीन न खोलें',
      'CRT स्क्रीन उघडू नका',
      'CRT glass can implode and contains hazardous material. Keep it intact and upright.',
      'CRT काँच फट सकता है और इसमें खतरनाक पदार्थ होते हैं। इसे साबुत और सीधा रखें।',
      'CRT काच फुटू शकते आणि त्यात धोकादायक पदार्थ असतात. ती अखंड व सरळ ठेवा.',
    ),
    _SafetyGuide(
      Icons.back_hand,
      'Protect hands and eyes',
      'हाथों और आँखों की सुरक्षा करें',
      'हात आणि डोळ्यांचे संरक्षण करा',
      'Wear gloves and eye protection. Do not pull apart unknown assemblies or sharp parts.',
      'दस्ताने और आँखों की सुरक्षा पहनें। अनजान या नुकीले हिस्से न खोलें।',
      'हातमोजे आणि डोळ्यांचे संरक्षण वापरा. अज्ञात किंवा धारदार भाग उघडू नका.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Safe handling · सुरक्षा')),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _guides.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Text(
                'Stop work and ask for trained help if material is leaking, hot, broken, or unknown.\n'
                'अगर कचरा रिस रहा हो, गर्म हो या टूटा हो तो काम रोककर मदद लें।\n'
                'कचरा गळत असेल, गरम किंवा तुटलेला असेल तर काम थांबवून मदत घ्या.',
                style: TextStyle(fontWeight: FontWeight.w600),
              );
            }
            final guide = _guides[index - 1];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.error.withValues(alpha: .12),
                      child: Icon(guide.icon, size: 30, color: AppColors.error),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(guide.english, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(guide.hindi, style: const TextStyle(fontSize: 15)),
                          Text(guide.marathi, style: const TextStyle(fontSize: 15)),
                          const SizedBox(height: 8),
                          Text(guide.bodyEnglish),
                          Text(guide.bodyHindi),
                          Text(guide.bodyMarathi),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _SafetyGuide {
  final IconData icon;
  final String english;
  final String hindi;
  final String marathi;
  final String bodyEnglish;
  final String bodyHindi;
  final String bodyMarathi;

  const _SafetyGuide(this.icon, this.english, this.hindi, this.marathi,
      this.bodyEnglish, this.bodyHindi, this.bodyMarathi);
}
