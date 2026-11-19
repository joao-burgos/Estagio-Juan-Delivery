package com.juan.api_delivery.pedido;

import com.juan.api_delivery.produto.ProdutoRepository;
import com.juan.api_delivery.produto.Vinho;
import com.juan.api_delivery.usuario.UsuarioRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static com.juan.api_delivery.shared.exception.MensagensErro.PEDIDO_ENTREGUE_NAO_CANCELA;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/** Regras de status do PedidoService com os repositórios mockados. */
@ExtendWith(MockitoExtension.class)
class PedidoServiceTest {

    @Mock
    private PedidoRepository repository;
    @Mock
    private UsuarioRepository usuarioRepository;
    @Mock
    private ItemPedidoRepository itemPedidoRepository;
    @Mock
    private ProdutoRepository produtoRepository;

    @InjectMocks
    private PedidoService service;

    private static Pedido pedido(StatusPedido status) {
        return Pedido.builder().id(1L).status(status).build();
    }

    private static Vinho vinho(int estoque) {
        Vinho vinho = new Vinho();
        vinho.setId(10L);
        vinho.setNome("Malbec");
        vinho.setEstoque(estoque);
        vinho.setAtivo(estoque > 0);
        return vinho;
    }

    @Test
    void cancelarPedidoPendenteDevolveOEstoque() {
        Pedido pedido = pedido(StatusPedido.PENDENTE);
        Vinho vinho = vinho(2);
        ItemPedido item = ItemPedido.builder().id(5L).quantidade(3).produto(vinho).pedido(pedido).build();
        when(repository.findById(1L)).thenReturn(Optional.of(pedido));
        when(itemPedidoRepository.findByPedidoId(1L)).thenReturn(List.of(item));
        when(produtoRepository.findByIdParaAtualizarEstoque(10L)).thenReturn(Optional.of(vinho));
        when(repository.save(any(Pedido.class))).thenAnswer(inv -> inv.getArgument(0));

        Pedido resultado = service.atualizarStatus(1L, StatusPedido.CANCELADO);

        assertThat(resultado.getStatus()).isEqualTo(StatusPedido.CANCELADO);
        assertThat(vinho.getEstoque()).isEqualTo(5);
    }

    @Test
    void cancelarPedidoEntregueERecusadoSemMexerNoEstoque() {
        Pedido pedido = pedido(StatusPedido.ENTREGUE);
        when(repository.findById(1L)).thenReturn(Optional.of(pedido));

        assertThatThrownBy(() -> service.atualizarStatus(1L, StatusPedido.CANCELADO))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage(PEDIDO_ENTREGUE_NAO_CANCELA);

        assertThat(pedido.getStatus()).isEqualTo(StatusPedido.ENTREGUE);
        verifyNoInteractions(itemPedidoRepository, produtoRepository);
        verify(repository, never()).save(any());
    }
}
