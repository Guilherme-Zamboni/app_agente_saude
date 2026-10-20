/// Normaliza um texto para comparação: minúsculas, sem acentos e sem
/// espaços sobrando. "  JOÃO   Zamboni" vira "joao zamboni".
const String _comAcento = 'àáâãäåèéêëìíîïòóôõöùúûüçñýÿ';
const String _semAcento = 'aaaaaaeeeeiiiiooooouuuucnyy';

String normalizar(String texto) {
  final minusculo = texto.trim().toLowerCase();
  final saida = StringBuffer();

  for (final unidade in minusculo.runes) {
    final caractere = String.fromCharCode(unidade);
    final indice = _comAcento.indexOf(caractere);
    saida.write(indice >= 0 ? _semAcento[indice] : caractere);
  }

  return saida.toString().replaceAll(RegExp(r'\s+'), ' ');
}