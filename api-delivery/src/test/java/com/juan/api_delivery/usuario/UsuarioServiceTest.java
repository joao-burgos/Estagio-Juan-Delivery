package com.juan.api_delivery.usuario;

import com.juan.api_delivery.shared.validation.CpfValidator;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;

import static com.juan.api_delivery.shared.exception.MensagensErro.CPF_JA_CADASTRADO;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Regras do UsuarioService com o repositório mockado. */
@ExtendWith(MockitoExtension.class)
class UsuarioServiceTest {

    private static final String CPF = "11144477735";
    private static final String OUTRO_CPF = "52998224725";

    @Mock
    private UsuarioRepository repository;

    @InjectMocks
    private UsuarioService service;

    private UsuarioDTO dtoBase;

    @BeforeEach
    void preparar() {
        dtoBase = new UsuarioDTO("Maria Silva", "11144477735", "maria@teste.com", "123456", "43999998888", null);
    }

    @Test
    void cadastrarComEmailJaExistenteLancaExcecao() {
        when(repository.findByEmailIgnoreCase("maria@teste.com"))
            .thenReturn(Optional.of(Usuario.builder().id(1L).email("maria@teste.com").build()));

        assertThatThrownBy(() -> service.criar(dtoBase))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage("Email já cadastrado");

        verify(repository, never()).save(any());
    }

    @Test
    void cadastrarComEmailJaExistenteEmMaiusculasDiferentesLancaExcecao() {
        dtoBase.setEmail("Maria@Teste.com");
        when(repository.findByEmailIgnoreCase("maria@teste.com"))
            .thenReturn(Optional.of(Usuario.builder().id(1L).email("maria@teste.com").build()));

        assertThatThrownBy(() -> service.criar(dtoBase))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage("Email já cadastrado");

        verify(repository, never()).save(any());
    }

    @Test
    void cadastrarComEmailNovoSalvaOUsuarioComPerfilClienteENormalizaOEmail() {
        dtoBase.setEmail("Maria@Teste.com");
        when(repository.findByEmailIgnoreCase("maria@teste.com")).thenReturn(Optional.empty());
        when(repository.save(any(Usuario.class))).thenAnswer(inv -> inv.getArgument(0));

        Usuario salvo = service.criar(dtoBase);

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

    private static UsuarioDTO dto(String email, String cpf) {
        UsuarioDTO dto = new UsuarioDTO();
        dto.setNome("Maria Silva");
        dto.setEmail(email);
        dto.setCpf(cpf);
        dto.setSenha("123456");
        dto.setTelefone("43999998888");
        return dto;
    }

    private static Usuario existente(Long id, String cpf) {
        return Usuario.builder().id(id).nome("Existente").email("existente" + id + "@teste.com")
            .senha("123456").cpf(cpf).telefone("4333334444").build();
    }

    @Nested
    class CpfUnicoNoCadastro {

        @Test
        void cpfDuplicadoERecusado() {
            when(repository.findByEmailIgnoreCase("novo@teste.com")).thenReturn(Optional.empty());
            when(repository.existsByCpf(CPF)).thenReturn(true);

            assertThatThrownBy(() -> service.criar(dto("novo@teste.com", CPF)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage(CPF_JA_CADASTRADO);
            verify(repository, never()).save(any());
        }

        /**
         * existsByCpf não filtra por ativo: o CPF de uma conta inativa também
         * bloqueia o cadastro (a conta só volta pela reativação do admin).
         */
        @Test
        void cpfDeContaInativaERecusado() {
            when(repository.findByEmailIgnoreCase("novo@teste.com")).thenReturn(Optional.empty());
            when(repository.existsByCpf(CPF)).thenReturn(true);

            assertThatThrownBy(() -> service.criar(dto("novo@teste.com", CPF)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage(CPF_JA_CADASTRADO);
            verify(repository, never()).findByAtivoTrue();
            verify(repository, never()).save(any());
        }

        @Test
        void cpfComMascaraEComparadoSoPelosDigitos() {
            when(repository.findByEmailIgnoreCase("novo@teste.com")).thenReturn(Optional.empty());
            when(repository.existsByCpf(CPF)).thenReturn(true);

            assertThatThrownBy(() -> service.criar(dto("novo@teste.com", "111.444.777-35")))
                .hasMessage(CPF_JA_CADASTRADO);
        }

        @Test
        void cpfCoringaPodeRepetir() {
            when(repository.findByEmailIgnoreCase(anyString())).thenReturn(Optional.empty());
            when(repository.save(any(Usuario.class))).thenAnswer(i -> i.getArgument(0));

            Usuario salvo = service.criar(dto("coringa@teste.com", CpfValidator.CPF_CORINGA));

            assertThat(salvo.getCpf()).isEqualTo(CpfValidator.CPF_CORINGA);
            verify(repository, never()).existsByCpf(anyString());
        }

        @Test
        void cpfNovoEAceito() {
            when(repository.findByEmailIgnoreCase("novo@teste.com")).thenReturn(Optional.empty());
            when(repository.existsByCpf(CPF)).thenReturn(false);
            when(repository.save(any(Usuario.class))).thenAnswer(i -> i.getArgument(0));

            assertThat(service.criar(dto("novo@teste.com", "111.444.777-35")).getCpf()).isEqualTo(CPF);
        }
    }

    @Nested
    class CpfUnicoNaEdicao {

        @Test
        void manterOProprioCpfFunciona() {
            Usuario usuario = existente(1L, CPF);
            when(repository.findById(1L)).thenReturn(Optional.of(usuario));
            when(repository.findByEmailIgnoreCase("existente1@teste.com")).thenReturn(Optional.of(usuario));
            when(repository.existsByCpfAndIdNot(CPF, 1L)).thenReturn(false);
            when(repository.save(any(Usuario.class))).thenAnswer(i -> i.getArgument(0));

            Usuario salvo = service.atualizar(1L, dto("existente1@teste.com", CPF));

            assertThat(salvo.getCpf()).isEqualTo(CPF);
            assertThat(salvo.getNome()).isEqualTo("Maria Silva");
        }

        @Test
        void cpfDeOutroUsuarioERecusado() {
            Usuario usuario = existente(1L, CPF);
            when(repository.findById(1L)).thenReturn(Optional.of(usuario));
            when(repository.findByEmailIgnoreCase("existente1@teste.com")).thenReturn(Optional.of(usuario));
            when(repository.existsByCpfAndIdNot(OUTRO_CPF, 1L)).thenReturn(true);

            assertThatThrownBy(() -> service.atualizar(1L, dto("existente1@teste.com", "529.982.247-25")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage(CPF_JA_CADASTRADO);
            assertThat(usuario.getCpf()).isEqualTo(CPF); // nada foi alterado
            verify(repository, never()).save(any());
        }

        @Test
        void cpfCoringaPodeRepetirNaEdicao() {
            Usuario usuario = existente(1L, CPF);
            when(repository.findById(1L)).thenReturn(Optional.of(usuario));
            when(repository.findByEmailIgnoreCase("existente1@teste.com")).thenReturn(Optional.of(usuario));
            when(repository.save(any(Usuario.class))).thenAnswer(i -> i.getArgument(0));

            Usuario salvo = service.atualizar(1L, dto("existente1@teste.com", CpfValidator.CPF_CORINGA));

            assertThat(salvo.getCpf()).isEqualTo(CpfValidator.CPF_CORINGA);
            verify(repository, never()).existsByCpfAndIdNot(anyString(), anyLong());
        }
    }
}
