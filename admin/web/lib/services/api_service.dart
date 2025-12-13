import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String token;
  final String baseUrl;
  ApiService(this.token, {String? base})
      : baseUrl = base ??
            const String.fromEnvironment('API_URL',
                defaultValue: 'http://localhost:8080');

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<dynamic>> getDeposits() async {
    final url = Uri.parse('$baseUrl/api/deposits');
    final res = await http.get(url, headers: _headers());
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Error fetching deposits: ${res.statusCode}');
  }

  Future<void> approveDeposit(String id,
      {bool approve = true, String observaciones = ''}) async {
    final url = Uri.parse('$baseUrl/api/deposits/$id/approve');
    final res = await http.post(url,
        headers: _headers(),
        body: jsonEncode({'approve': approve, 'observaciones': observaciones}));
    if (res.statusCode != 200)
      throw Exception('Approve failed: ${res.statusCode}');
  }

  Future<List<dynamic>> getUsers() async {
    final url = Uri.parse('$baseUrl/api/users');
    final res = await http.get(url, headers: _headers());
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Error fetching users: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getCaja() async {
    final url = Uri.parse('$baseUrl/api/caja');
    final res = await http.get(url, headers: _headers());
    if (res.statusCode == 200)
      return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error fetching caja: ${res.statusCode}');
  }

  Future<void> setCaja(double saldo) async {
    final url = Uri.parse('$baseUrl/api/caja');
    final res = await http.post(url,
        headers: _headers(), body: jsonEncode({'saldo': saldo}));
    if (res.statusCode != 200)
      throw Exception('Error setting caja: ${res.statusCode}');
  }

  Future<Map<String, double>> getAggregateTotals() async {
    final url = Uri.parse('$baseUrl/api/aggregate_totals');
    final res = await http.get(url, headers: _headers());
    if (res.statusCode == 200)
      return Map<String, double>.from(jsonDecode(res.body) as Map);
    throw Exception('Error fetching aggregates: ${res.statusCode}');
  }

  Future<String?> createAporte(String idUsuario, String tipo, double monto,
      {String? descripcion, String? archivoUrl}) async {
    final url = Uri.parse('$baseUrl/api/aportes');
    final res = await http.post(url,
        headers: _headers(),
        body: jsonEncode({
          'idUsuario': idUsuario,
          'tipo': tipo,
          'monto': monto,
          'descripcion': descripcion,
          'archivoUrl': archivoUrl
        }));
    if (res.statusCode == 200)
      return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as String?;
    throw Exception('Error creating aporte: ${res.statusCode}');
  }

  Future<void> approvePrestamo(String id,
      {required bool approve,
      double? montoAprobado,
      double? interes,
      int? plazoMeses,
      String observaciones = ''}) async {
    final url = Uri.parse('$baseUrl/api/prestamos/$id/approve');
    final body = {'approve': approve, 'observaciones': observaciones};
    if (montoAprobado != null) body['montoAprobado'] = montoAprobado;
    if (interes != null) body['interes'] = interes;
    if (plazoMeses != null) body['plazoMeses'] = plazoMeses;
    final res =
        await http.post(url, headers: _headers(), body: jsonEncode(body));
    if (res.statusCode != 200)
      throw Exception('Error approving loan: ${res.statusCode}');
  }

  Future<void> addPagoPrestamo(String id, Map<String, dynamic> pago) async {
    final url = Uri.parse('$baseUrl/api/prestamos/$id/pagos');
    final res =
        await http.post(url, headers: _headers(), body: jsonEncode(pago));
    if (res.statusCode != 200)
      throw Exception('Error adding payment: ${res.statusCode}');
  }
}
