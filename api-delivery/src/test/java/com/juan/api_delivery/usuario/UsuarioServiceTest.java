package com.juan.api_delivery.usuario;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Testes unitários de {@link UsuarioService}, com o repository mockado. */
@ExtendWith(MockitoExtension.class)
class UsuarioServiceTest {

    @Mock
    private UsuarioRepository repository;

    @InjectMocks
    private UsuarioService service;

    private UsuarioDTO dto;

    @BeforeEach
    void preparar() {
        dto = new UsuarioDTO("Maria Silva", "11144477735", "maria@teste.com", "123456", "43999998888", null);
    }

    @Test
    void cadastrarComEmailJaExistenteLancaExcecao() {
        when(repository.findByEmailIgnoreCase("maria@teste.com"))
            .thenReturn(Optional.of(Usuario.builder().id(1L).email("maria@teste.com").build()));

        assertThatThrownBy(() -> service.criar(dto))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage("Email já cadastrado");

        verify(repository, never()).save(any());
    }

    @Test
    void cadastrarComEmailJaExistenteEmMaiusculasDiferentesLancaExcecao() {
        dto.setEmail("Maria@Teste.com");
        when(repository.findByEmailIgnoreCase("maria@teste.com"))
            .thenReturn(Optional.of(Usuario.builder().id(1L).email("maria@teste.com").build()));

        assertThatThrownBy(() -> service.criar(dto))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage("Email já cadastrado");

        verify(repository, never()).save(any());
    }

    @Test
    void cadastrarComEmailNovoSalvaOUsuarioComPerfilClienteENormalizaOEmail() {
        dto.setEmail("Maria@Teste.com");
        when(repository.findByEmailIgnoreCase("maria@teste.com")).thenReturn(Optional.empty());
        when(repository.save(any(Usuario.class))).thenAnswer(inv -> inv.getArgument(0));

        Usuario salvo = service.criar(dto);

        ArgumentCaptor<Usuario> captor = ArgumentCaptor.forClass(Usuario.class);
        verify(repository).save(captor.capture());
        assertThat(captor.getValue().getEmail()).isEqualTo("maria@teste.com");
        assertThat(salvo.getPerfil()).isEqualTo(PerfilUsuario.CLIENTE);
        assertThat(salvo.getDataCadastro()).isEqualTo(LocalDate.now());
    }

    @Test
    void reativarUsuarioInativoMudaOStatusParaAtivo() {
        Usuario inativo = Usuario.builder().id(5L).email("inativo@teste.com").ativo(false).build();
        when(repository.findById(5L)).thenReturn(Optional.of(inativo));
        when(repository.save(any(Usuario.class))).thenAnswer(inv -> inv.getArgument(0));

        Usuario resultado = service.reativar(5L);

        assertThat(resultado.isAtivo()).isTrue();
        verify(repository).save(inativo);
    }

    @Test
    void reativarUsuarioJaAtivoLancaExcecao() {
        Usuario ativo = Usuario.builder().id(6L).email("ativo@teste.com").ativo(true).build();
        when(repository.findById(6L)).thenReturn(Optional.of(ativo));

        assertThatThrownBy(() -> service.reativar(6L))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage("Usuário já está ativo");

        verify(repository, never()).save(any());
    }
}
