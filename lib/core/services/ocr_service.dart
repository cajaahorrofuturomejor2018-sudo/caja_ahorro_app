import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// PDF text extraction is optional and requires adding a separate package (e.g. pdf_text or pdf_render)
// If you enable PDF parsing, uncomment an appropriate import and implement PDF->text conversion.

/// Servicio de OCR usando Google ML Kit Text Recognition.
/// Requiere configuración nativa y añadir `google_mlkit_text_recognition` al pubspec.
class OCRService {
  final _textRecognizer = TextRecognizer();

  /// Extrae texto, monto y fecha desde una imagen local.
  Future<Map<String, dynamic>> extractVoucherData(
    File imageFile, {
    String? registeredAccount,
  }) async {
    String textoCompleto = '';
    RecognizedText? recognizedText;

    if (imageFile.path.toLowerCase().endsWith('.pdf')) {
      // PDF detected: this build does not perform PDF text extraction.
      // To enable PDF OCR, add a PDF parsing/rendering package and extract text from the first page.
      textoCompleto = '';
    } else {
      final inputImage = InputImage.fromFile(imageFile);
      recognizedText = await _textRecognizer.processImage(inputImage);
      textoCompleto = recognizedText.text;
    }

    // Extraer por líneas si se tiene RecognizedText (imagen) o dividir texto (pdf)
    final candidates = <Map<String, dynamic>>[];
    final lines = <String>[];
    if (recognizedText != null) {
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          lines.add(line.text);
        }
      }
    } else {
      lines.addAll(textoCompleto.split(RegExp(r"\r?\n")));
    }

    int lineIndex = 0;
    for (final lineText in lines) {
      final montoReg = RegExp(r"([€\$]?\s?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2}))");
      final matches = montoReg.allMatches(lineText);
      for (final m in matches) {
        var raw = m.group(1)!;
        raw = raw.replaceAll(RegExp(r"[^0-9,\.]"), '');
        final lastComma = raw.lastIndexOf(',');
        final lastDot = raw.lastIndexOf('.');
        if (lastComma > lastDot) {
          raw = raw.replaceAll('.', '');
          raw = raw.replaceAll(',', '.');
        } else if (lastDot > lastComma) {
          raw = raw.replaceAll(',', '');
        }
        final value = double.tryParse(raw) ?? 0.0;
        final hasKeyword = RegExp(
          r"\b(total|importe|amount|total:|saldo|efectivo)\b",
          caseSensitive: false,
        ).hasMatch(lineText);
        candidates.add({
          'amount': value,
          'line': lineText,
          'lineIndex': lineIndex,
          'hasKeyword': hasKeyword,
        });
      }
      lineIndex++;
    }

    // Determinar candidato preferido
    Map<String, dynamic>? preferred;
    if (candidates.isNotEmpty) {
      final withKeyword = candidates
          .where((c) => c['hasKeyword'] == true)
          .toList();
      if (withKeyword.isNotEmpty) {
        withKeyword.sort(
          (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
        );
        preferred = withKeyword.first;
      } else {
        candidates.sort(
          (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
        );
        preferred = candidates.first;
      }
    }

    final parsed = parseText(textoCompleto);

    // Extraer nombre y cuenta a partir de las líneas
    String? detectedName;
    String? detectedAccountRaw;
    String? detectedAccountDigits;
    String? detectedAccountFirst3;
    String? detectedAccountLast3;
    String? detectedAccountLast4;

    // keywords that indicate the destination account or beneficiary
    final destinoKeywords = RegExp(
      r"\b(a|para|destino|destinatario|beneficiario|acredita|acreditada|acreditado|cuenta destino|cta destino|a la cuenta)\b",
      caseSensitive: false,
    );

    for (final l in lines) {
      final low = l.toLowerCase();
      if (detectedName == null &&
          RegExp(
            r"\b(cliente|nombre|nombre:|cliente:)\b",
            caseSensitive: false,
          ).hasMatch(low)) {
        final parts = l.split(':');
        if (parts.length > 1) {
          detectedName = parts.sublist(1).join(':').trim();
        } else {
          final after = l
              .replaceAll(
                RegExp(r"cliente|nombre|:|\(|\)", caseSensitive: false),
                '',
              )
              .trim();
          if (after.isNotEmpty) detectedName = after;
        }
      }

      // If the line contains an explicit 'cuenta' keyword, capture obvious sequences
      if (detectedAccountRaw == null &&
          RegExp(
            r"\b(cuenta|nro|número de cuenta|nro de cuenta|cta)\b",
            caseSensitive: false,
          ).hasMatch(low)) {
        final seqs = RegExp(r"[\d*.]+").allMatches(l);
        for (final s in seqs) {
          final raw = s.group(0) ?? '';
          final digits = raw.replaceAll(RegExp(r"[^0-9]"), '');
          if (digits.length >= 6) {
            detectedAccountRaw = raw;
            detectedAccountDigits = digits;
            break;
          }
          if (digits.length >= 3) {
            detectedAccountRaw = raw;
            detectedAccountDigits = digits;
            break;
          }
        }
      }

      // Heurística para detectar cuenta destino: si la línea contiene palabras como 'a', 'para', 'destino',
      // preferimos la secuencia de dígitos que aparece después de la palabra clave.
      if (detectedAccountDigits == null && destinoKeywords.hasMatch(low)) {
        // buscar secuencias de dígitos en la línea
        final allDigits = RegExp(r"[\d*.]+").allMatches(l).toList();
        if (allDigits.isNotEmpty) {
          // intentamos localizar la palabra clave y elegir la secuencia más próxima hacia la derecha
          final kwMatch = destinoKeywords.firstMatch(low);
          if (kwMatch != null) {
            final kwEnd = kwMatch.end;
            // buscar la primera secuencia que aparece después del índice kwEnd
            Match? chosen;
            for (final s in allDigits) {
              if (s.start >= kwEnd) {
                chosen = s;
                break;
              }
            }
            // si no hay secuencia después, tomar la última secuencia de la línea
            chosen ??= allDigits.isNotEmpty ? allDigits.last : null;
            if (chosen != null) {
              final raw = chosen.group(0) ?? '';
              final digits = raw.replaceAll(RegExp(r"[^0-9]"), '');
              if (digits.isNotEmpty) {
                detectedAccountRaw = raw;
                detectedAccountDigits = digits;
              }
            }
          }
        }
      }
    }

    if (detectedAccountDigits != null && detectedAccountDigits.length >= 6) {
      detectedAccountFirst3 = detectedAccountDigits.substring(0, 3);
      detectedAccountLast3 = detectedAccountDigits.substring(
        detectedAccountDigits.length - 3,
      );
      if (detectedAccountDigits.length >= 4) {
        detectedAccountLast4 = detectedAccountDigits.substring(
          detectedAccountDigits.length - 4,
        );
      }
    } else if (detectedAccountDigits != null &&
        detectedAccountDigits.length >= 3) {
      detectedAccountLast3 = detectedAccountDigits.substring(
        detectedAccountDigits.length - 3,
      );
    }

    // Verificar contra la cuenta registrada si se proporciona
    bool? accountMatches;
    if (registeredAccount != null &&
        registeredAccount.isNotEmpty &&
        detectedAccountDigits != null) {
      final regDigits = registeredAccount.replaceAll(RegExp(r"[^0-9]"), '');
      // Match por dígitos completos, luego últimos 4 y últimos 3
      if (regDigits == detectedAccountDigits) {
        accountMatches = true;
      } else if (detectedAccountLast4 != null &&
          regDigits.endsWith(detectedAccountLast4)) {
        accountMatches = true;
      } else if (detectedAccountLast3 != null &&
          regDigits.endsWith(detectedAccountLast3)) {
        accountMatches = true;
      } else {
        accountMatches = false;
      }
    }

    return {
      'texto': textoCompleto,
      'parsed': parsed,
      'candidates': candidates,
      'preferred': preferred,
      'detected_name': detectedName,
      'detected_account_raw': detectedAccountRaw,
      'detected_account_digits': detectedAccountDigits,
      'detected_account_first3': detectedAccountFirst3,
      'detected_account_last3': detectedAccountLast3,
      'detected_account_last4': detectedAccountLast4,
      'account_matches': accountMatches,
    };
  }

  /// Analiza un texto ya extraído y obtiene monto y fecha si es posible.
  static Map<String, dynamic> parseText(String textoCompleto) {
    double monto = 0.0;
    String fecha = '';

    // Buscar posibles montos (números con decimales o sin decimales)
    // Admitir formatos con separador de miles y símbolo de moneda opcional.
    // Ejemplos: "$1,234.56", "1.234,56", "1234.56", "1234,56"
    final montoReg = RegExp(r"([€\$]?\s?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2}))");
    final matchMonto = montoReg.firstMatch(textoCompleto);
    if (matchMonto != null) {
      var raw = matchMonto.group(1)!;
      // Normalizar separadores: si viene con ',' como separador decimal (ej. 1.234,56)
      // detectamos la última ocurrencia de ',' o '.' y la tratamos como separador decimal.
      raw = raw.replaceAll(RegExp(r"[^0-9,\.]"), '');
      final lastComma = raw.lastIndexOf(',');
      final lastDot = raw.lastIndexOf('.');
      if (lastComma > lastDot) {
        // formato europeo: '.' como miles, ',' como decimal
        raw = raw.replaceAll('.', '');
        raw = raw.replaceAll(',', '.');
      } else if (lastDot > lastComma) {
        // formato anglosajón: ',' as thousands, '.' as decimal
        raw = raw.replaceAll(',', '');
      }
      monto = double.tryParse(raw) ?? 0.0;
    }

    // Try multiple date formats: dd/mm/yyyy, dd-mm-yyyy, dd MMM yyyy (spanish and english), Day dd MMM yyyy
    final fechaRegexes = [
      RegExp(r"(\d{1,2}/\d{1,2}/\d{2,4})"),
      RegExp(r"(\d{1,2}-\d{1,2}-\d{2,4})"),
      RegExp(r"(\d{1,2}\s+[A-Za-zñÑ\.]{3,}\s+\d{4})"),
      RegExp(r"[A-Za-zñÑ]+\s+(\d{1,2}\s+[A-Za-zñÑ\.]{3,}\s+\d{4})"),
    ];
    String? found;
    for (final r in fechaRegexes) {
      final m = r.firstMatch(textoCompleto);
      if (m != null) {
        found = m.groupCount >= 1 ? m.group(1) ?? m.group(0) : m.group(0);
        if (found != null && found.isNotEmpty) {
          final normalized = _parseDateStringToIso(found);
          if (normalized != null) {
            fecha = normalized;
            break;
          }
        }
      }
    }

    return {'texto': textoCompleto, 'monto': monto, 'fecha': fecha};
  }

  /// Intenta normalizar distintas representaciones de fecha a ISO (yyyy-MM-dd).
  /// Soporta: 04/11/2025, 04-11-2025, 04 nov 2025, Lunes 04 Nov. 2025, etc.
  static String? _parseDateStringToIso(String input) {
    input = input.trim();
    try {
      // dd/mm/yyyy o dd-mm-yyyy
      final dmy = RegExp(r"^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$");
      final m = dmy.firstMatch(input);
      if (m != null) {
        final dd = int.parse(m.group(1)!);
        final mm = int.parse(m.group(2)!);
        var yy = int.parse(m.group(3)!);
        if (yy < 100) yy += 2000;
        final dt = DateTime(yy, mm, dd);
        return dt.toIso8601String().split('T').first;
      }

      // dd MMM yyyy (month names spanish/english, allow dot after abbreviation)
      final parts = input.split(RegExp(r"\s+"));
      // find day token and month token
      int? day;
      String? monthToken;
      int? year;
      for (var i = 0; i < parts.length; i++) {
        final p = parts[i].replaceAll(RegExp(r"[,\.]"), '');
        if (RegExp(r"^\d{1,2}").hasMatch(p) && day == null) {
          day = int.parse(RegExp(r"\d{1,2}").firstMatch(p)!.group(0)!);
          if (i + 1 < parts.length) {
            monthToken = parts[i + 1].replaceAll(RegExp(r"[,\.]"), '');
          }
          if (i + 2 < parts.length &&
              RegExp(r"^\d{4}").hasMatch(parts[i + 2])) {
            year = int.parse(
              RegExp(r"\d{4}").firstMatch(parts[i + 2])!.group(0)!,
            );
          }
          break;
        }
      }
      if (day != null && monthToken != null && year != null) {
        final months = {
          'ene': 1,
          'ene.': 1,
          'feb': 2,
          'mar': 3,
          'abr': 4,
          'apr': 4,
          'may': 5,
          'jun': 6,
          'jul': 7,
          'ago': 8,
          'aug': 8,
          'sep': 9,
          'set': 9,
          'oct': 10,
          'nov': 11,
          'dic': 12,
          'dec': 12,
          'nov.': 11,
        };
        final token = monthToken.toLowerCase();
        int? mm = months[token];
        if (mm == null) {
          // try prefix match
          for (final k in months.keys) {
            if (token.startsWith(k)) {
              mm = months[k];
              break;
            }
          }
        }
        if (mm != null) {
          final dt = DateTime(year, mm, day);
          return dt.toIso8601String().split('T').first;
        }
      }
    } catch (_) {}
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
