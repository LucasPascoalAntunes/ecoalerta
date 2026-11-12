import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'modelos.dart';
import 'sessao.dart';

class ApiException implements Exception {
  ApiException(this.mensagem, {this.codigo = 'erro', this.status, this.semConexao = false});
  final String mensagem;
  final String codigo;
  final int? status;
  final bool semConexao;
  bool get naoAutenticado => status == 401;
  @override
  String toString() => mensagem;
}

ApiException traduzErro(Object e) {
  if (e is ApiException) return e;
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Tempo esgotado ao falar com o servidor. Tente novamente.', codigo: 'timeout', semConexao: true);
      case DioExceptionType.connectionError:
        return ApiException(
          'Sem conexão com o servidor. Verifique a internet ou o endereço em Perfil > Servidor.',
          codigo: 'sem_conexao',
          semConexao: true,
        );
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        final status = e.response?.statusCode;
        if (data is Map && data['mensagem'] != null) {
          return ApiException(data['mensagem'].toString(), codigo: data['erro']?.toString() ?? 'erro', status: status);
        }
        return ApiException('O servidor respondeu com erro $status.', status: status);
      case DioExceptionType.cancel:
        return ApiException('Requisição cancelada.', codigo: 'cancelado');
      default:
        return ApiException('Falha de rede: ${e.message ?? e.error}', codigo: 'rede', semConexao: true);
    }
  }
  if (e is FormatException) return ApiException('Resposta inválida do servidor.');
  return ApiException('Erro inesperado: $e');
}

final dioProvider = Provider<Dio>((ref) {
  final base = ref.watch(configProvider).servidorUrl;
  final token = ref.watch(sessaoProvider.select((s) => s?.token));
  final dio = Dio(BaseOptions(
    baseUrl: base,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 25),
    sendTimeout: const Duration(seconds: 40),
    headers: {'Accept': 'application/json'},
  ));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    if (token != null) o.headers['Authorization'] = 'Bearer $token';
    h.next(o);
  }));
  return dio;
});

final apiProvider = Provider<Api>((ref) => Api(ref.watch(dioProvider)));

class Api {
  Api(this._dio);
  final Dio _dio;

  Future<dynamic> _run(Future<Response<dynamic>> Function() f) async {
    try {
      return (await f()).data;
    } catch (e) {
      throw traduzErro(e);
    }
  }

  Map<String, dynamic> _m(dynamic d) => Map<String, dynamic>.from(d as Map);
  List<Map<String, dynamic>> _l(dynamic d) => (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<Map<String, dynamic>> health() async => _m(await _run(() => _dio.get('/api/health')));

  Future<({String token, Usuario usuario})> login(String email, String senha) async {
    final d = _m(await _run(() => _dio.post('/api/auth/login', data: {'email': email, 'senha': senha})));
    return (token: d['token'] as String, usuario: Usuario.fromJson(_m(d['usuario'])));
  }

  Future<({String token, Usuario usuario})> registrar(String nome, String email, String senha) async {
    final d = _m(await _run(() => _dio.post('/api/auth/registrar', data: {'nome': nome, 'email': email, 'senha': senha})));
    return (token: d['token'] as String, usuario: Usuario.fromJson(_m(d['usuario'])));
  }

  Future<Usuario> eu() async => Usuario.fromJson(_m(await _run(() => _dio.get('/api/auth/eu'))));

  Future<List<Relato>> listarRelatos(FiltroRelatos f) async {
    final q = <String, dynamic>{
      if (f.categoria != null) 'categoria': f.categoria,
      if (f.status != null) 'status': f.status,
      if (f.busca != null && f.busca!.isNotEmpty) 'busca': f.busca,
      if (f.lat != null) 'lat': f.lat,
      if (f.lon != null) 'lon': f.lon,
      if (f.raioKm != null) 'raio_km': f.raioKm,
      if (f.ordenar != null) 'ordenar': f.ordenar,
      if (f.meus) 'meus': 'true',
      'limite': 500,
    };
    return _l(await _run(() => _dio.get('/api/relatos', queryParameters: q))).map(Relato.fromJson).toList();
  }

  Future<Relato> obterRelato(int id) async => Relato.fromJson(_m(await _run(() => _dio.get('/api/relatos/$id'))));

  Future<Relato> criarRelato(Map<String, dynamic> corpo) async =>
      Relato.fromJson(_m(await _run(() => _dio.post('/api/relatos', data: corpo))));

  Future<Relato> confirmar(int id) async => Relato.fromJson(_m(await _run(() => _dio.post('/api/relatos/$id/confirmar'))));

  Future<Relato> alterarStatus(int id, String status, String? observacao) async => Relato.fromJson(
      _m(await _run(() => _dio.patch('/api/relatos/$id/status', data: {'status': status, 'observacao': observacao}))));

  Future<List<HistoricoStatus>> historico(int id) async =>
      _l(await _run(() => _dio.get('/api/relatos/$id/historico'))).map(HistoricoStatus.fromJson).toList();

  Future<List<Comentario>> comentarios(int id) async =>
      _l(await _run(() => _dio.get('/api/relatos/$id/comentarios'))).map(Comentario.fromJson).toList();

  Future<Comentario> comentar(int id, String texto) async =>
      Comentario.fromJson(_m(await _run(() => _dio.post('/api/relatos/$id/comentarios', data: {'texto': texto}))));

  Future<void> excluir(int id) async => _run(() => _dio.delete('/api/relatos/$id'));

  Future<QualidadeAr> qualidadeAr(double lat, double lon) async =>
      QualidadeAr.fromJson(_m(await _run(() => _dio.get('/api/ambiente/ar', queryParameters: {'lat': lat, 'lon': lon}))));

  Future<Clima> clima(double lat, double lon) async =>
      Clima.fromJson(_m(await _run(() => _dio.get('/api/ambiente/clima', queryParameters: {'lat': lat, 'lon': lon}))));

  Future<Endereco> geocode(double lat, double lon) async =>
      Endereco.fromJson(_m(await _run(() => _dio.get('/api/geocode/reverso', queryParameters: {'lat': lat, 'lon': lon}))));

  Future<List<PontoMonitorado>> pontos() async =>
      _l(await _run(() => _dio.get('/api/ambiente/pontos'))).map(PontoMonitorado.fromJson).toList();

  Future<HistoricoAr> historicoAr({int? pontoId, double? lat, double? lon, int horas = 168}) async => HistoricoAr.fromJson(_m(
      await _run(() => _dio.get('/api/ambiente/historico', queryParameters: {
            'ponto_id': ?pontoId,
            'lat': ?lat,
            'lon': ?lon,
            'horas': horas,
          }))));

  Future<int> coletarAgora() async => (_m(await _run(() => _dio.post('/api/ambiente/coletar')))['pontos_coletados'] as num).toInt();

  Future<Estatisticas> estatisticas() async => Estatisticas.fromJson(_m(await _run(() => _dio.get('/api/estatisticas'))));

  Future<String> exportarCsv() async =>
      (await _run(() => _dio.get('/api/relatorios/relatos.csv', options: Options(responseType: ResponseType.plain)))) as String;
}
