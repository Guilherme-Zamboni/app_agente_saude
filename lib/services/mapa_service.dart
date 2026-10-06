import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cuida da imagem do mapa de cada microárea: envio pelo coordenador,
/// download e cache local para funcionar offline.
class MapaService {
  static final _cliente = Supabase.instance.client;
  static const _bucket = 'mapas';

  /// Envia a imagem e devolve a URL pública.
  /// Calcula também a proporção para o app desenhar sem distorcer.
  static Future<Map<String, dynamic>> enviar({
    required String territorioId,
    required File arquivo,
  }) async {
    final extensao = arquivo.path.split('.').last.toLowerCase();
    final nome = '$territorioId.$extensao';

    await _cliente.storage.from(_bucket).upload(
          nome,
          arquivo,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = _cliente.storage.from(_bucket).getPublicUrl(nome);
    final proporcao = await _proporcaoDe(arquivo);

    return {'url': url, 'proporcao': proporcao};
  }

  /// Descobre a proporção (largura / altura) da imagem.
  static Future<double> _proporcaoDe(File arquivo) async {
    final bytes = await arquivo.readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descritor = await ui.ImageDescriptor.encoded(buffer);
    final proporcao = descritor.width / descritor.height;
    descritor.dispose();
    buffer.dispose();
    return proporcao;
  }

  /// Caminho do arquivo em cache para uma URL.
  static Future<File> _arquivoCache(String url) async {
    final pasta = await getApplicationDocumentsDirectory();
    final nome = md5.convert(utf8.encode(url)).toString();
    return File('${pasta.path}/mapa_$nome');
  }

  /// Devolve o arquivo local da imagem, baixando se ainda não estiver
  /// em cache. Retorna null se não houver imagem ou se falhar o download
  /// (o app cai na imagem padrão).
  static Future<File?> obter(String? url) async {
    if (url == null || url.isEmpty) return null;

    try {
      final arquivo = await _arquivoCache(url);
      if (await arquivo.exists()) return arquivo;

      final resposta = await _cliente.storage
          .from(_bucket)
          .download(Uri.parse(url).pathSegments.last);

      await arquivo.writeAsBytes(resposta);
      return arquivo;
    } catch (e) {
      debugPrint('>>> Falha ao baixar mapa: $e');
      return null;
    }
  }

  /// Limpa o cache de uma imagem, para forçar novo download
  /// quando o coordenador substituir o mapa.
  static Future<void> limparCache(String url) async {
    try {
      final arquivo = await _arquivoCache(url);
      if (await arquivo.exists()) await arquivo.delete();
    } catch (_) {}
  }
}