/// Valutazione della periodicità di un servizio per una data (RF-05, §5).
///
/// Un `service_id` è attivo in un giorno se:
///  - rientra nella finestra `start_date`…`end_date` di `calendar.txt` **e** il
///    giorno della settimana è attivo;
/// con override delle eccezioni `calendar_dates.txt`:
///  - `exception_type = 1` (added)   → forza attivo in quella data;
///  - `exception_type = 2` (removed) → forza non attivo in quella data.
///
/// L'eccezione ha **sempre** la precedenza sulla regola ricorrente.
library;

import '../data/gtfs_models.dart';

/// Converte una [DateTime] in intero `YYYYMMDD` (confrontabile come i campi GTFS).
int dateToInt(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Vero se [serviceId] è attivo nel giorno [date].
bool isServiceActive(
  String serviceId,
  DateTime date, {
  required Map<String, Calendar> calendars,
  required Map<String, List<CalendarDate>> calendarDatesByService,
}) {
  final ymd = dateToInt(date);

  // Le eccezioni hanno precedenza sulla regola ricorrente.
  final exceptions = calendarDatesByService[serviceId];
  if (exceptions != null) {
    for (final ex in exceptions) {
      if (ex.date == ymd) {
        return ex.exceptionType == ExceptionType.added;
      }
    }
  }

  final cal = calendars[serviceId];
  if (cal == null) return false;

  if (ymd < cal.startDate || ymd > cal.endDate) return false;

  // DateTime.weekday: 1 = lunedì … 7 = domenica → indice 0..6.
  return cal.activeDays[date.weekday - 1];
}
