package com.juan.api_delivery.produto;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Testes unitários da entidade {@link Produto} (regra de estoque/ativo),
 * sem Spring e sem banco — usa {@link Acessorio} como instância concreta.
 */
class ProdutoTest {

    private Produto produtoComEstoque(int estoque) {
        return Acessorio.builder()
            .nome("Saca-rolhas")
            .preco(new BigDecimal("49.90"))
            .estoque(estoque)
            .ativo(estoque > 0)
            .build();
    }

    @Test
    void baixarEstoqueDiminuiAQuantidade() {
        Produto produto = produtoComEstoque(10);

        produto.baixarEstoque(3);

        assertThat(produto.getEstoque()).isEqualTo(7);
        assertThat(produto.isAtivo()).isTrue();
    }

    @Test
    void baixarEstoqueAteZeroDeixaOProdutoInativo() {
        Produto produto = produtoComEstoque(2);

        produto.baixarEstoque(2);

        assertThat(produto.getEstoque()).isZero();
        assertThat(produto.isAtivo()).isFalse();
    }

    @Test
    void devolverEstoqueAumentaAQuantidadeEReativaOProdutoInativo() {
        Produto produto = produtoComEstoque(1);
        produto.baixarEstoque(1); // zera e inativa
        assertThat(produto.isAtivo()).isFalse();

        produto.devolverEstoque(1);

        assertThat(produto.getEstoque()).isEqualTo(1);
        assertThat(produto.isAtivo()).isTrue();
    }

    /**
     * {@link Produto#baixarEstoque} não valida se a quantidade cabe no
     * estoque — o javadoc do método diz explicitamente "já validada pelo
     * chamador". Quem garante isso é {@link com.juan.api_delivery.pedido.ItemPedidoService#adicionar},
     * testado em ItemPedidoServiceTest. Aqui só documentamos esse contrato:
     * a entidade sozinha permite estoque negativo se for chamada sem o guard.
     */
    @Test
    void baixarEstoqueNaoValidaSozinhaEDeixaOEstoqueNegativoSemGuardExterno() {
        Produto produto = produtoComEstoque(2);

        produto.baixarEstoque(3);

        assertThat(produto.getEstoque()).isEqualTo(-1);
    }
}
