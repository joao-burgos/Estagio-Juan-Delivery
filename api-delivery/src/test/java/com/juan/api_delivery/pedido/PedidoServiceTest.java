package com.juan.api_delivery.pedido;

import com.juan.api_delivery.produto.Acessorio;
import com.juan.api_delivery.produto.Produto;
import com.juan.api_delivery.produto.ProdutoRepository;
import com.juan.api_delivery.usuario.UsuarioRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Testes unitários de {@link PedidoService}, focados no cancelamento do pedido. */
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

    private Pedido pedido;
    private Produto vinho;
    private Produto acessorio;

    @BeforeEach
    void preparar() {
        pedido = Pedido.builder().id(1L).status(StatusPedido.PENDENTE).valorTotal(new BigDecimal("229.60")).build();
        vinho = Acessorio.builder().id(10L).nome("Malbec").preco(new BigDecimal("89.90")).estoque(0).ativo(false).build();
        acessorio = Acessorio.builder().id(20L).nome("Saca-rolhas").preco(new BigDecimal("49.90")).estoque(1).ativo(true).build();
    }

    @Test
    void cancelarDevolveOEstoqueDeCadaItem() {
        when(repository.findById(1L)).thenReturn(Optional.of(pedido));
        when(itemPedidoRepository.findByPedidoId(1L)).thenReturn(List.of(
            ItemPedido.builder().produto(vinho).quantidade(2).precoUnit(vinho.getPreco()).build(),
            ItemPedido.builder().produto(acessorio).quantidade(3).precoUnit(acessorio.getPreco()).build()));
        when(produtoRepository.findByIdParaAtualizarEstoque(10L)).thenReturn(Optional.of(vinho));
        when(produtoRepository.findByIdParaAtualizarEstoque(20L)).thenReturn(Optional.of(acessorio));
        when(repository.save(any(Pedido.class))).thenAnswer(inv -> inv.getArgument(0));

        Pedido resultado = service.atualizarStatus(1L, StatusPedido.CANCELADO);

        assertThat(resultado.getStatus()).isEqualTo(StatusPedido.CANCELADO);
        assertThat(vinho.getEstoque()).isEqualTo(2);
        assertThat(vinho.isAtivo()).isTrue(); // reativado ao voltar a ter estoque
        assertThat(acessorio.getEstoque()).isEqualTo(4);
    }

    @Test
    void cancelarPedidoJaCanceladoNaoDevolveOEstoqueDeNovo() {
        pedido.setStatus(StatusPedido.CANCELADO);
        when(repository.findById(1L)).thenReturn(Optional.of(pedido));

        Pedido resultado = service.atualizarStatus(1L, StatusPedido.CANCELADO);

        assertThat(resultado.getStatus()).isEqualTo(StatusPedido.CANCELADO);
        verify(itemPedidoRepository, never()).findByPedidoId(any());
        verify(produtoRepository, never()).findByIdParaAtualizarEstoque(any());
    }

    @Test
    void mudarStatusParaOutroDiferenteDeCanceladoNaoMexeNoEstoque() {
        when(repository.findById(1L)).thenReturn(Optional.of(pedido));
        when(repository.save(any(Pedido.class))).thenAnswer(inv -> inv.getArgument(0));

        Pedido resultado = service.atualizarStatus(1L, StatusPedido.CONFIRMADO);

        assertThat(resultado.getStatus()).isEqualTo(StatusPedido.CONFIRMADO);
        verify(itemPedidoRepository, never()).findByPedidoId(any());
        verify(produtoRepository, never()).findByIdParaAtualizarEstoque(any());
    }
}
