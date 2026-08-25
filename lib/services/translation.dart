class TranslationService {
  static const Map<String, Map<String, String>> _translations = {
    'english': {
      'reminder_title': 'Medicine Reminder',
      'reminder_body': 'Hello {{name}}, it is time to take your medicine: {{medicine}}. Instructions: {{instruction}}.',
      'before_food': 'Before food',
      'after_food': 'After food',
      'with_food': 'With food',
      'none': 'No special instructions',
      'good_morning': 'Good Morning',
      'good_afternoon': 'Good Afternoon',
      'good_evening': 'Good Evening',
      'good_night': 'Good Night',
      'daily_progress': 'Daily Progress',
      'medicines_taken': 'medicines taken',
      'next_dose': 'Next dose',
      'todays_schedule': "Today's Schedule",
      'schedule_for': 'Schedule for',
      'linked_elder_safety': 'Linked Elder Safety Status',
      'mark_taken': 'Mark Medicine Taken',
      'weekly_adherence': 'Weekly Adherence',
      'ai_care_tips': 'AI Care Tips',
      'taken': 'TAKEN',
      'no_scheduled_medicines': 'No scheduled medicines today.',
      'tts_call_done': 'Voice Call reminder done',
      'whatsapp_done': 'WhatsApp reminder done',
      'local_alarm_done': 'Alarm reminder done',
    },
    'hindi': {
      'reminder_title': 'दवा की याद दिलाएं',
      'reminder_body': 'नमस्ते {{name}}, आपकी दवा लेने का समय हो गया है: {{medicine}}। निर्देश: {{instruction}}।',
      'before_food': 'खाने से पहले',
      'after_food': 'खाने के बाद',
      'with_food': 'खाने के साथ',
      'none': 'कोई विशेष निर्देश नहीं',
      'good_morning': 'शुभ प्रभात',
      'good_afternoon': 'शुभ दोपहर',
      'good_evening': 'शुभ संध्या',
      'good_night': 'शुभ रात्रि',
      'daily_progress': 'दैनिक प्रगति',
      'medicines_taken': 'दवाएं ली गईं',
      'next_dose': 'अगली खुराक',
      'todays_schedule': 'आज का शेड्यूल',
      'schedule_for': 'शेड्यूल तिथि',
      'linked_elder_safety': 'लिंक्ड बुजुर्ग सुरक्षा स्थिति',
      'mark_taken': 'दवा ली गई दर्ज करें',
      'weekly_adherence': 'साप्ताहिक पालन',
      'ai_care_tips': 'एआ‌ई स्वास्थ्य युक्तियाँ',
      'taken': 'ले ली',
      'no_scheduled_medicines': 'आज कोई निर्धारित दवाएं नहीं हैं।',
      'tts_call_done': 'वॉयस कॉल रिमाइंडर भेजा गया',
      'whatsapp_done': 'व्हाट्सएप रिमाइंडर भेजा गया',
      'local_alarm_done': 'अलार्म बज गया',
    },
    'marathi': {
      'reminder_title': 'औषध स्मरणपत्र',
      'reminder_body': 'नमस्ते {{name}}, तुमची औषध घेण्याची वेळ झाली आहे: {{medicine}}। सूचना: {{instruction}}।',
      'before_food': 'जेवणापूर्वी',
      'after_food': 'जेवणानंतर',
      'with_food': 'जेवणासोबत',
      'none': 'कोणत्याही विशेष सूचना नाहीत',
      'good_morning': 'शुभ सकाळ',
      'good_afternoon': 'शुभ दुपार',
      'good_evening': 'शुभ संध्याकाळ',
      'good_night': 'शुभ रात्री',
      'daily_progress': 'दैनिक प्रगती',
      'medicines_taken': 'औषधे घेतली',
      'next_dose': 'पुढील डोस',
      'todays_schedule': 'आजचे वेळापत्रक',
      'schedule_for': 'वेळापत्रक दिनांक',
      'linked_elder_safety': 'लिंक्ड वृद्ध सुरक्षा स्थिती',
      'mark_taken': 'औषध घेतले नोंदवा',
      'weekly_adherence': 'साप्ताहिक पालन',
      'ai_care_tips': 'एआय आरोग्य टिप्स',
      'taken': 'घेतले',
      'no_scheduled_medicines': 'आज कोणतेही नियोजित औषध नाही.',
      'tts_call_done': 'व्हॉइस कॉल स्मरणपत्र पाठवले',
      'whatsapp_done': 'व्हॉट्सॲप स्मरणपत्र पाठवले',
      'local_alarm_done': 'अलार्म स्मरणपत्र वाजले',
    },
    'telugu': {
      'reminder_title': 'మందుల రిమైండర్',
      'reminder_body': 'నమస్తే {{name}}, మీ మందులు వేసుకునే సమయం అయింది: {{medicine}}. సూచనలు: {{instruction}}.',
      'before_food': 'ఆహారానికి ముందు',
      'after_food': 'ఆహారం తర్వాత',
      'with_food': 'ఆహారంతో పాటు',
      'none': 'ఎలాంటి ప్రత్యేక సూచనలు లేవు',
    },
    'tamil': {
      'reminder_title': 'மருந்து நினைவூட்டல்',
      'reminder_body': 'வணக்கம் {{name}}, உங்கள் மருந்து எடுத்துக்கொள்ளும் நேரம் இது: {{medicine}}. அறிவுறுத்தல்கள்: {{instruction}}.',
      'before_food': 'உணவுக்கு முன்',
      'after_food': 'உணவுக்கு பின்',
      'with_food': 'உணவுடன்',
      'none': 'சிறப்பு அறிவுறுத்தல்கள் எதுவும் இல்லை',
    },
    'bengali': {
      'reminder_title': 'ওষুধের অনুস্মারক',
      'reminder_body': 'নমস্কার {{name}}, আপনার ওষুধ খাওয়ার সময় হয়েছে: {{medicine}}। নির্দেশাবলী: {{instruction}}।',
      'before_food': 'খাওয়ার আগে',
      'after_food': 'খাওয়ার পরে',
      'with_food': 'খাবারের সাথে',
      'none': 'কোন বিশেষ নির্দেশ নেই',
    },
    'gujarati': {
      'reminder_title': 'દવા રિમાઇન્ડર',
      'reminder_body': 'નમસ્તે {{name}}, તમારી દવા લેવાનો સમય થઈ ગયો છે: {{medicine}}. સૂચનાઓ: {{instruction}}.',
      'before_food': 'જમ્યા પહેલા',
      'after_food': 'જમ્યા પછી',
      'with_food': 'જમવાની સાથે',
      'none': 'કોઈ ખાસ સૂચના નથી',
    },
    'kannada': {
      'reminder_title': 'ಔಷಧ ರಿಮೈಂಡರ್',
      'reminder_body': 'ನಮસ્ತೆ {{name}}, ನಿಮ್ಮ ಔಷಧ ತೆಗೆದುಕೊಳ್ಳುವ ಸಮಯ ಬಂದಿದೆ: {{medicine}}. ಸೂಚನೆಗಳು: {{instruction}}.',
      'before_food': 'ಊಟಕ್ಕೆ ಮುන්න',
      'after_food': 'ಊಟದ ನಂತರ',
      'with_food': 'ಊಟದ ಜೊತೆ',
      'none': 'ಯಾವುದే ವಿಶೇಷ ಸೂಚನೆಗಳಿಲ್ಲ',
    },
    'malayalam': {
      'reminder_title': 'മരുന്ന് ഓർമ്മപ്പെടുത്തൽ',
      'reminder_body': 'ഹലോ {{name}}, നിങ്ങളുടെ മരുന്ന് കഴിക്കാനുള്ള സമയമായി: {{medicine}}. നിർദ്ദേശങ്ങൾ: {{instruction}}.',
      'before_food': 'ഭക്ഷണത്തിന് മുൻപ്',
      'after_food': 'ഭക്ഷണത്തിന് ശേഷം',
      'with_food': 'ഭക്ഷണത്തോടൊപ്പം',
      'none': 'പ്രത്യേക നിർദ്ദേശങ്ങൾ ഒന്നുമില്ല',
    },
    'punjabi': {
      'reminder_title': 'ਦਵਾਈ ਦਾ ਰੀਮਾਈਂਡਰ',
      'reminder_body': 'ਸਤਿ ਸ੍ਰੀ ਅਕาล {{name}}, ਤੁਹਾਡੀ ਦਵਾਈ ਲੈਣ ਦਾ ਸਮਾਂ ਹੋ ਗਿਆ ਹੈ: {{medicine}}। ਨਿਰਦੇਸ਼: {{instruction}}।',
      'before_food': 'ਖਾਣ ਤੋਂ ਪਹਿਲਾਂ',
      'after_food': 'ਖਾਣ ਤੋਂ ਬਾਅਦ',
      'with_food': 'ਖਾਣ ਦੇ ਨਾਲ',
      'none': 'ਕੋਈ ਖਾਸ ਨਿਰਦੇਸ਼ ਨਹੀਂ',
    }
  };

  static String getTranslation(String lang, String key) {
    final language = lang.toLowerCase();
    if (!_translations.containsKey(language)) {
      return _translations['english']![key] ?? '';
    }
    return _translations[language]![key] ?? _translations['english']![key] ?? '';
  }

  static String generateReminderText({
    required String language,
    required String userName,
    required String medicineName,
    required String foodInstructionKey,
  }) {
    final template = getTranslation(language, 'reminder_body');
    final instruction = getTranslation(language, foodInstructionKey);

    return template
        .replaceAll('{{name}}', userName)
        .replaceAll('{{medicine}}', medicineName)
        .replaceAll('{{instruction}}', instruction);
  }

  static List<String> getSupportedLanguages() {
    return _translations.keys.toList();
  }
}
