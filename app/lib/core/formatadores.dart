import 'package:intl/intl.dart';

DateTime? parseData(String? s) {
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}

String dataCurta(String? s) {
  final d = parseData(s);
  if (d == null) return '-';
  return DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(d);
}

String horaCurta(String? s) {
  final d = parseData(s);
  if (d == null) return '-';
  return DateFormat('HH:mm', 'pt_BR').format(d);
}

String diaMes(String? s) {
  final d = parseData(s);
  if (d == null) return '-';
  return DateFormat('dd/MM', 'pt_BR').format(d);
}

String tempoRelativo(String? s) {
  final d = parseData(s);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  if (diff.inDays < 7) return 'há ${diff.inDays} dia${diff.inDays > 1 ? 's' : ''}';
  return DateFormat('dd/MM/yyyy', 'pt_BR').format(d);
}

String distancia(double? km) {
  if (km == null) return '';
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

String numero(double? v, [int casas = 0]) {
  if (v == null) return '-';
  return NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: casas).format(v);
}

String horas(double? h) {
  if (h == null) return '-';
  if (h < 24) return '${h.toStringAsFixed(0)} h';
  return '${(h / 24).toStringAsFixed(1).replaceAll('.', ',')} dias';
}
