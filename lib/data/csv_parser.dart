/// Parser CSV minimale per i file GTFS del bundle.
///
/// I file seed sono CSV UTF-8 semplici: separatore `,`, nessun campo con
/// virgolette o virgole interne. Il parser resta volutamente essenziale (niente
/// dipendenza esterna), ma gestisce comunque i campi quotati `"..."` per
/// robustezza verso feed futuri prodotti dalla pipeline (Fase 2).
library;

/// Converte il contenuto CSV in una lista di righe come mappa header→valore.
///
/// - Salta righe completamente vuote.
/// - Normalizza i terminatori di riga (`\r\n`, `\r`, `\n`).
/// - Rimuove un eventuale BOM UTF-8 iniziale.
List<Map<String, String>> parseCsv(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');

  // Trova la prima riga non vuota = header.
  var index = 0;
  while (index < lines.length && lines[index].trim().isEmpty) {
    index++;
  }
  if (index >= lines.length) return const [];

  final header = _splitRow(_stripBom(lines[index]));
  index++;

  final rows = <Map<String, String>>[];
  for (; index < lines.length; index++) {
    final line = lines[index];
    if (line.trim().isEmpty) continue;
    final values = _splitRow(line);
    final row = <String, String>{};
    for (var c = 0; c < header.length; c++) {
      row[header[c]] = c < values.length ? values[c] : '';
    }
    rows.add(row);
  }
  return rows;
}

String _stripBom(String s) =>
    s.startsWith('﻿') ? s.substring(1) : s;

/// Divide una riga CSV gestendo i campi quotati con `"`.
List<String> _splitRow(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQuotes) {
      if (ch == '"') {
        // Doppia virgoletta dentro un campo quotato = virgoletta letterale.
        if (i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buffer.write(ch);
      }
    } else {
      if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
  }
  fields.add(buffer.toString());
  return fields.map((f) => f.trim()).toList();
}

/// Converte `HH:MM:SS` (anche con ore ≥ 24) in secondi dalla mezzanotte.
///
/// Ritorna `null` se il valore è vuoto o malformato.
int? parseGtfsTime(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final s = parts.length >= 3 ? int.tryParse(parts[2]) : 0;
  if (h == null || m == null || s == null) return null;
  return h * 3600 + m * 60 + s;
}
