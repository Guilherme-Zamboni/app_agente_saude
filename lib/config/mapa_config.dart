import 'dart:math' as math;

/// Ajustes visuais dos mapas, em um só lugar.
const double zoomMaximo = 8.0;
const double tamanhoPino = 20;
const double tamanhoPinoDestacado = 28;
const double fontePinoNumero = 8;

/// Quanto o pino acompanha o zoom do mapa:
/// 0.0 = tamanho fixo na tela (não cresce)
/// 0.5 = cresce, mas bem menos que o mapa
/// 1.0 = cresce junto com o mapa, como se fosse parte da imagem
const double crescimentoPino = 0.5;

/// Fator aplicado ao pino para a escala atual do mapa.
double escalaDoPino(double escalaMapa) =>
    math.pow(escalaMapa, crescimentoPino - 1).toDouble();