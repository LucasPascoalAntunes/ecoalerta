import 'package:flutter/material.dart';

class Categoria {
  const Categoria({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.icone,
    required this.cor,
  });
  final String id;
  final String nome;
  final String descricao;
  final IconData icone;
  final Color cor;
}

const kCategorias = <Categoria>[
  Categoria(id: 'alagamento', nome: 'Alagamento', descricao: 'Ruas, avenidas ou imóveis tomados pela água', icone: Icons.water, cor: Color(0xFF1E88E5)),
  Categoria(id: 'poluicao_ar', nome: 'Poluição do ar', descricao: 'Fumaça, fuligem, odor químico ou ar carregado', icone: Icons.factory, cor: Color(0xFF6D4C41)),
  Categoria(id: 'descarte_irregular', nome: 'Descarte irregular', descricao: 'Lixo, entulho ou resíduos em local impróprio', icone: Icons.delete_sweep, cor: Color(0xFFF4511E)),
  Categoria(id: 'desmatamento', nome: 'Desmatamento', descricao: 'Corte ou supressão de vegetação e árvores', icone: Icons.forest, cor: Color(0xFF2E7D32)),
  Categoria(id: 'queimada', nome: 'Queimada', descricao: 'Fogo em vegetação, terreno ou lixo', icone: Icons.local_fire_department, cor: Color(0xFFD32F2F)),
  Categoria(id: 'invasao_manancial', nome: 'Invasão de manancial', descricao: 'Ocupação irregular em área de proteção de água', icone: Icons.holiday_village, cor: Color(0xFF00897B)),
  Categoria(id: 'transito', nome: 'Trânsito e transporte', descricao: 'Congestionamento crítico ou falha no transporte público', icone: Icons.directions_bus, cor: Color(0xFF3949AB)),
  Categoria(id: 'inversao_termica', nome: 'Inversão térmica', descricao: 'Ar parado, névoa seca e poluição concentrada', icone: Icons.foggy, cor: Color(0xFF757575)),
  Categoria(id: 'poluicao_sonora', nome: 'Poluição sonora', descricao: 'Ruído excessivo e persistente', icone: Icons.volume_up, cor: Color(0xFF8E24AA)),
  Categoria(id: 'poluicao_agua', nome: 'Poluição da água', descricao: 'Esgoto, óleo ou espuma em corpo d\'água', icone: Icons.science, cor: Color(0xFF00ACC1)),
  Categoria(id: 'outro', nome: 'Outro problema', descricao: 'Ocorrência que não se encaixa nas demais', icone: Icons.warning_amber, cor: Color(0xFFFB8C00)),
];

Categoria categoriaPorId(String id) =>
    kCategorias.firstWhere((c) => c.id == id, orElse: () => kCategorias.last);

class StatusInfo {
  const StatusInfo(this.id, this.rotulo, this.cor, this.icone);
  final String id;
  final String rotulo;
  final Color cor;
  final IconData icone;
}

const kStatus = <StatusInfo>[
  StatusInfo('aberto', 'Aberta', Color(0xFFE53935), Icons.error_outline),
  StatusInfo('em_analise', 'Em análise', Color(0xFFF9A825), Icons.search),
  StatusInfo('resolvido', 'Resolvida', Color(0xFF43A047), Icons.check_circle_outline),
  StatusInfo('invalido', 'Inválida', Color(0xFF9E9E9E), Icons.block),
];

StatusInfo statusPorId(String id) =>
    kStatus.firstWhere((s) => s.id == id, orElse: () => kStatus.first);

const kGravidades = <int, String>{
  1: 'Baixa',
  2: 'Leve',
  3: 'Média',
  4: 'Alta',
  5: 'Crítica',
};

Color corGravidade(int g) => switch (g) {
      1 => const Color(0xFF66BB6A),
      2 => const Color(0xFF9CCC65),
      3 => const Color(0xFFFFCA28),
      4 => const Color(0xFFFF7043),
      _ => const Color(0xFFD32F2F),
    };

Color corRisco(String nivel) => switch (nivel) {
      'alto' => const Color(0xFFD32F2F),
      'moderado' => const Color(0xFFF9A825),
      _ => const Color(0xFF43A047),
    };
