package com.juan.api_delivery.produto;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.math.BigDecimal;
import java.util.Set;

import static com.juan.api_delivery.shared.exception.MensagensErro.TEOR_ALCOOL_INVALIDO;
import static org.assertj.core.api.Assertions.assertThat;

/**
 * Valida as anotações de Bean Validation de {@link Vinho} direto com o
 * Validator do jakarta.validation, sem subir o Spring.
 */
class VinhoValidacaoTest {

    private static ValidatorFactory factory;
    private static Validator validator;

    @BeforeAll
    static void criarValidator() {
        factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @AfterAll
    static void fecharValidator() {
        factory.close();
    }

    private static Vinho vinho(double teorAlcool, String harmonizacao) {
        return Vinho.builder()
            .nome("Malbec Reserva")
            .preco(new BigDecimal("89.90"))
            .estoque(10)
            .categoria(CategoriaProduto.VINHO_TINTO)
            .paisOrigem("Argentina")
            .safra(2020)
            .teorAlcool(teorAlcool)
            .harmonizacao(harmonizacao)
            .build();
    }

    @ParameterizedTest
    @ValueSource(doubles = {7.0, 13.5, 20.0})
    void teorAlcoolDentroDoLimitePassa(double teor) {
        Set<ConstraintViolation<Vinho>> violacoes = validator.validate(vinho(teor, "Carnes vermelhas"));

        assertThat(violacoes).isEmpty();
    }

    @ParameterizedTest
    @ValueSource(doubles = {6.9, 20.1})
    void teorAlcoolForaDoLimiteERecusado(double teor) {
        Set<ConstraintViolation<Vinho>> violacoes = validator.validate(vinho(teor, "Carnes vermelhas"));

        assertThat(violacoes)
            .extracting(ConstraintViolation::getMessage)
            .contains(TEOR_ALCOOL_INVALIDO);
    }

    @Test
    void harmonizacaoVaziaEAceitaFicaNull() {
        Vinho vinho = vinho(13.5, null);

        Set<ConstraintViolation<Vinho>> violacoes = validator.validate(vinho);

        assertThat(violacoes).isEmpty();
        assertThat(vinho.getHarmonizacao()).isNull();
    }
}
