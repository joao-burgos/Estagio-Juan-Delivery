import 'package:flutter/material.dart';
import '../models/item_pedido.dart';
import '../models/pedido.dart';
import '../../perfil/models/endereco.dart';
import '../services/pedido_service.dart';
import 'pedido_concluido_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dialogo_confirmacao.dart';

const _kStatusLabels = {
  'PENDENTE': 'Pendente',
  'CONFIRMADO': 'Confirmado',
  'EM_PREPARO': 'Em preparo',
  'EM_ENTREGA': 'Em entrega',
  'ENTREGUE': 'Entregue',
  'CANCELADO': 'Cancelado',
};

const _kStatusCores = {
  'PENDENTE': Color(0xFFEF6C00), // laranja
  'CONFIRMADO': Color(0xFF1565C0), // azul
  'EM_PREPARO': Color(0xFF6A1B9A), // roxo
  'EM_ENTREGA': Color(0xFFF9A825), // amarelo
  'ENTREGUE': Color(0xFF2E7D32), // verde
  'CANCELADO': Color(0xFFC62828), // vermelho
};

const _kVerdeEntrega = Color(0xFF2E7D32);

/// Tela de detalhes de um pedido: busca o pedido (GET /pedidos/{id}) e seus
/// itens (GET /pedidos/{pedidoId}/itens), exibindo status, itens, endereço
/// de entrega e os botões para o cliente confirmar que recebeu o pedido ou
/// cancelá-lo (os dois pedem confirmação antes de chamar a API).
class DetalhesPedidoScreen extends StatefulWidget {
  final int pedidoId;

  const DetalhesPedidoScreen({super.key, required this.pedidoId});

  @override
  State<DetalhesPedidoScreen> createState() => _DetalhesPedidoScreenState();
}

class _DetalhesPedidoScreenState extends State<DetalhesPedidoScreen> {
  final _service = PedidoService();

  Pedido? _pedido;
  List<ItemPedido> _itens = [];
  bool _carregando = true;
  String? _erro;

  /// Status sendo enviado à API ('ENTREGUE' ou 'CANCELADO'); null quando nada
  /// está em andamento. Enquanto não for null os dois botões ficam
  /// desabilitados (evita toque duplo) e o botão tocado mostra carregando.
  String? _statusEnviando;

  /// Erro devolvido pela API ao mudar o status, exibido acima dos botões.
  String? _erroAcao;

  /// Aviso curto exibido no topo do card do pedido depois de cancelar.
  String? _aviso;

  bool get _atualizandoStatus => _statusEnviando != null;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final pedido = await _service.buscarPorId(widget.pedidoId);
      final itens = await _service.listarItensPorPedido(widget.pedidoId);
      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _itens = itens;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
        _carregando = false;
      });
    }
  }

  // O backend não recalcula valorTotal ao adicionar itens (fica em 0), então
  // o total exibido é somado a partir dos itens, que carregam o preço
  // praticado no momento da compra.
  double get _totalCalculado => _itens.fold(0.0, (soma, item) => soma + item.subtotal);

  Future<void> _confirmarEntrega() async {
    final confirmar = await mostrarDialogoConfirmacao(
      context,
      titulo: 'Confirmar entrega?',
      mensagem: 'Confirme apenas se você já recebeu o pedido #${widget.pedidoId}.',
      textoVoltar: 'Voltar',
      textoConfirmar: 'Confirmar',
      corConfirmar: _kVerdeEntrega,
    );
    if (!confirmar || !mounted) return;

    if (!await _enviarStatus('ENTREGUE') || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pedido confirmado! Obrigado pela sua compra!'),
        backgroundColor: Colors.green.shade700,
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PedidoConcluidoScreen()),
      (route) => false,
    );
  }

  Future<void> _cancelarPedido() async {
    final confirmar = await mostrarDialogoConfirmacao(
      context,
      titulo: 'Cancelar pedido?',
      mensagem: 'O pedido #${widget.pedidoId} será cancelado e os itens voltarão ao estoque. '
          'Essa ação não pode ser desfeita.',
      textoVoltar: 'Voltar',
      textoConfirmar: 'Cancelar pedido',
      corConfirmar: kPerigo,
    );
    if (!confirmar || !mounted) return;

    // O backend devolve o estoque dos itens ao cancelar.
    if (!await _enviarStatus('CANCELADO') || !mounted) return;
    final atual = _pedido!;
    setState(() {
      _pedido = Pedido(
        id: atual.id,
        usuarioId: atual.usuarioId,
        status: 'CANCELADO',
        dataPedido: atual.dataPedido,
        valorTotal: atual.valorTotal,
        enderecosUsuario: atual.enderecosUsuario,
      );
      _aviso = 'Pedido cancelado. Os itens voltaram ao estoque.';
    });
  }

  /// Envia o novo status (PATCH /pedidos/{id}/status). Em caso de erro,
  /// guarda a mensagem da API em [_erroAcao] e retorna false.
  Future<bool> _enviarStatus(String status) async {
    setState(() {
      _statusEnviando = status;
      _erroAcao = null;
    });
    try {
      await _service.atualizarStatus(widget.pedidoId, status);
      return true;
    } catch (e) {
      if (mounted) setState(() => _erroAcao = e.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      if (mounted) setState(() => _statusEnviando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Detalhes do Pedido'),
        backgroundColor: kPrimary,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _erro != null
              ? _buildErro()
              : _buildConteudo(_pedido!),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(_erro!, textAlign: TextAlign.center, style: const TextStyle(color: kTextSecondary)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _carregar, child: const Text('TENTAR NOVAMENTE')),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo(Pedido pedido) {
    final cor = _kStatusCores[pedido.status] ?? kTextSecondary;
    final label = _kStatusLabels[pedido.status] ?? pedido.status;
    // Os botões de confirmar entrega e de cancelar aparecem para qualquer
    // pedido ainda em andamento (PENDENTE, CONFIRMADO, EM_PREPARO,
    // EM_ENTREGA); somem quando o pedido já está no histórico (ENTREGUE ou
    // CANCELADO).
    final emAberto = pedido.status != 'ENTREGUE' && pedido.status != 'CANCELADO';
    final endereco = pedido.enderecosUsuario.isNotEmpty ? pedido.enderecosUsuario.first : null;

    // Os botões ficam no fim da área rolável, acima da barra do total (e não
    // por baixo dela), então nunca ficam escondidos.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCabecalho(pedido, cor, label),
                const SizedBox(height: 20),
                const Text('Itens', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                for (final item in _itens) _buildItem(item),
                if (endereco != null) ...[
                  const SizedBox(height: 8),
                  const Text('Endereço de entrega',
                      style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _buildEndereco(endereco),
                ],
                if (_erroAcao != null) ...[
                  const SizedBox(height: 16),
                  _buildErroAcao(_erroAcao!),
                ],
                if (emAberto) ...[
                  const SizedBox(height: 24),
                  _buildBotaoConfirmarEntrega(),
                  const SizedBox(height: 12),
                  _buildBotaoCancelarPedido(),
                ],
              ],
            ),
          ),
        ),
        _buildRodapeTotal(),
      ],
    );
  }

  Widget _buildCabecalho(Pedido pedido, Color cor, String label) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_aviso != null) ...[
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: cor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_aviso!, style: TextStyle(color: cor, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pedido #${pedido.id}',
                style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pedido.dataPedido != null ? _formatarData(pedido.dataPedido!) : '-',
            style: const TextStyle(color: kTextSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEndereco(Endereco endereco) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on, color: kPrimary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${endereco.rua}, ${endereco.numero}',
                  style: const TextStyle(color: kTextPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(endereco.bairro, style: const TextStyle(color: kTextSecondary, fontSize: 13)),
                Text('${endereco.cidade} - ${endereco.estado}',
                    style: const TextStyle(color: kTextSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Os dois botões têm a mesma largura e altura (um abaixo do outro).
  static const _kTamanhoBotao = Size.fromHeight(52);
  static const _kTextoBotao = TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.6);

  Widget _carregandoBotao(Color cor) => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: cor),
      );

  Widget _buildBotaoConfirmarEntrega() {
    return ElevatedButton.icon(
      key: const Key('botao_confirmar_entrega'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kVerdeEntrega,
        foregroundColor: Colors.white,
        minimumSize: _kTamanhoBotao,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _atualizandoStatus ? null : _confirmarEntrega,
      icon: _statusEnviando == 'ENTREGUE' ? _carregandoBotao(Colors.white) : const Icon(Icons.check_circle_outline),
      label: const Text('CONFIRMAR ENTREGA', style: _kTextoBotao),
    );
  }

  Widget _buildBotaoCancelarPedido() {
    return OutlinedButton.icon(
      key: const Key('botao_cancelar_pedido'),
      style: OutlinedButton.styleFrom(
        foregroundColor: kPerigo,
        minimumSize: _kTamanhoBotao,
        side: BorderSide(color: kPerigo.withValues(alpha: _atualizandoStatus ? 0.38 : 1), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _atualizandoStatus ? null : _cancelarPedido,
      icon: _statusEnviando == 'CANCELADO' ? _carregandoBotao(kPerigo) : const Icon(Icons.cancel_outlined),
      label: const Text('CANCELAR PEDIDO', style: _kTextoBotao),
    );
  }

  Widget _buildErroAcao(String mensagem) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPerigo.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPerigo.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: kPerigo, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(mensagem, style: const TextStyle(color: kPerigo, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildItem(ItemPedido item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: kPrimary.withValues(alpha: 0.1),
            child: Icon(
              item.produto.isAcessorio ? Icons.local_mall_outlined : Icons.wine_bar_outlined,
              color: kPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.produto.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantidade}x R\$ ${item.precoUnit.toStringAsFixed(2)}',
                  style: const TextStyle(color: kTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            'R\$ ${item.subtotal.toStringAsFixed(2)}',
            style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRodapeTotal() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total', style: TextStyle(color: kTextSecondary, fontSize: 15)),
            Text(
              'R\$ ${_totalCalculado.toStringAsFixed(2)}',
              style: const TextStyle(color: kPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year} às $hora:$minuto';
  }
}
