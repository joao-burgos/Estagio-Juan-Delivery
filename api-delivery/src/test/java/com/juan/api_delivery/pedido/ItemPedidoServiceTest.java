package com.juan.api_delivery.pedido;

import com.juan.api_delivery.produto.Acessorio;
import com.juan.api_delivery.produto.Produto;
import com.juan.api_delivery.produto.ProdutoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Testes unitários de {@link ItemPedidoService}, com os repositories mockados. */
@ExtendWith(MockitoExtension.class)
class ItemPedidoServiceTest {

    @Mock
    private ItemPedidoRepository repository;
    @Mock
    private PedidoRepository pedidoRepository;
    @Mock
    private ProdutoRepository produtoRepository;

    @InjectMocks
    private ItemPedidoService service;

    private Pedido pedido;
    private Produto produto;

    @BeforeEach
    void preparar() {
        pedido = Pedido.builder().id(1L).status(StatusPedido.PENDENTE).valorTotal(BigDecimal.ZERO).build();
        produto = Acessorio.builder().id(10L).nome("Saca-rolhas").preco(new BigDecimal("49.90"))
            .estoque(5).ativo(true).build();
    }

    private ItemPedidoDTO dto(long produtoId, int quantidade) {
        return new ItemPedidoDTO(produtoId, quantidade);
    }

    @Test
    void adicionarBaixaOEstoqueESalvaOItem() {
        when(pedidoRepository.findById(1L)).thenReturn(Optional.of(pedido));
        when(produtoRepository.findByIdParaAtualizarEstoque(10L)).thenReturn(Optional.of(produto));
        when(repository.save(any(ItemPedido.class))).thenAnswer(inv -> inv.getArgument(0));
        when(repository.findByPedidoId(1L)).thenReturn(List.of(
            ItemPedido.builder().produto(produto).quantidade(3).precoUnit(produto.getPreco()).build()));

        ItemPedido item = service.adicionar(1L, dto(10L, 3));

        assertThat(item.getQuantidade()).isEqualTo(3);
        assertThat(item.getPrecoUnit()).isEqualByComparingTo("49.90");
        assertThat(produto.getEstoque()).isEqualTo(2);
        assertThat(produto.isAtivo()).isTrue();
    }

    @Test
    void adicionarRecalculaOValorTotalDoPedido() {
        when(pedidoRepository.findById(1L)).thenReturn(Optional.of(pedido));
        when(produtoRepository.findByIdParaAtualizarEstoque(10L)).thenReturn(Optional.of(produto));
        when(repository.save(any(ItemPedido.class))).thenAnswer(inv -> inv.getArgument(0));
        when(repository.findByPedidoId(1L)).thenReturn(List.of(
            ItemPedido.builder().produto(produto).quantidade(3).precoUnit(new BigDecimal("49.90")).build()));

        service.adicionar(1L, dto(10L, 3));

        ArgumentCaptor<Pedido> captor = ArgumentCaptor.forClass(Pedido.class);
        verify(pedidoRepository).save(captor.capture());
        assertThat(captor.getValue().getValorTotal()).isEqualByComparingTo("149.70");
    }

    @Test
    void adicionarComProdutoInativoLancaExcecaoENaoSalvaOItem() {
        produto.setAtivo(false);
        when(pedidoRepository.findById(1L)).thenReturn(Optional.of(pedido));
        when(produtoRepository.findByIdParaAtualizarEstoque(10L)).thenReturn(Optional.of(produto));

        assertThatThrownBy(() -> service.adicionar(1L, dto(10L, 1)))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage("Produto indisponível");

        verify(repository, never()).save(any());
        assertThat(produto.getEstoque()).isEqualTo(5); // estoque intocado
    }

    @Test
    void adicionarComQuantidadeMaiorQueOEstoqueLancaExcecaoENaoAlteraOEstoque() {
        when(pedidoRepository.findById(1L)).thenReturn(Optional.of(pedido));
        when(produtoRepository.findByIdParaAtualizarEstoque(10L)).thenReturn(Optional.of(produto));

        assertThatThrownBy(() -> service.adicionar(1L, dto(10L, 6)))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage("Estoque insuficiente para Saca-rolhas. Disponível: 5");

        verify(repository, never()).save(any());
        assertThat(produto.getEstoque()).isEqualTo(5);
        verify(pedidoRepository, times(1)).findById(1L); // só a busca do pedido, nunca o save
        verify(pedidoRepository, never()).save(any());
    }

    @Test
    void adicionarEmPedidoCanceladoLancaExcecao() {
        pedido.setStatus(StatusPedido.CANCELADO);
        when(pedidoRepository.findById(1L)).thenReturn(Optional.of(pedido));

        assertThatThrownBy(() -> service.adicionar(1L, dto(10L, 1)))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage("Pedido cancelado não pode ser alterado");

        verify(produtoRepository, never()).findByIdParaAtualizarEstoque(anyLong());
        verify(repository, never()).save(any());
    }
}
