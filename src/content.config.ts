import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

/**
 * TRAVAS DE BUILD (seção 6.4 do briefing) — o build FALHA se:
 *  1. Imóvel renderizável (status ≠ pausado) sem autorização escrita — trava legal
 *     (Decreto 81.871/78, art. 5º).
 *  2. Imóvel vendido sem `vendido_em` — case sem data não é prova, é alegação.
 * A trava 3 (formato do WhatsApp) mora em src/config.ts e roda em toda importação.
 */

const imoveis = defineCollection({
  loader: glob({ base: "./src/content/imoveis", pattern: "**/[^_]*.md" }),
  schema: ({ image }) =>
    z
      .object({
        ref: z.string().regex(/^FL-\d{4}$/, 'Use o formato "FL-0000" no campo ref.'),
        status: z.enum(["disponivel", "reservado", "vendido", "pausado"]),
        tipo: z.enum(["apartamento", "casa-condominio", "casa", "terreno"]),
        finalidade: z.enum(["venda", "locacao", "venda-locacao"]).default("venda"),
        exclusivo: z.boolean().default(false),
        // Sem default de propósito: publicar exige decisão consciente.
        autorizacao_escrita: z.boolean({
          required_error:
            "Campo obrigatório 'autorizacao_escrita' ausente. Só publique imóvel com contrato/autorização escrita (Decreto 81.871/78, art. 5º).",
        }),

        titulo: z.string().min(8),
        condominio: z.string().optional(), // slug — relaciona com a coleção condominios
        bairro: z.string().min(2),         // slug — relaciona com a coleção bairros/território
        cidade: z.string().default("Sorocaba"),
        uf: z.string().default("SP"),

        valor: z.number().int().positive(),
        exibir_valor: z.boolean().optional(), // default condicional aplicado no transform
        valor_condominio: z.number().nonnegative().optional(),
        valor_iptu: z.number().nonnegative().optional(),
        aceita_financiamento: z.boolean().default(false),
        aceita_fgts: z.boolean().default(false),
        aceita_permuta: z.boolean().default(false),

        area_util: z.number().positive(),
        area_total: z.number().positive().optional(),
        dormitorios: z.number().int().nonnegative(),
        suites: z.number().int().nonnegative().default(0),
        banheiros: z.number().int().positive(),
        vagas: z.number().int().nonnegative(),
        vaga_coberta: z.boolean().optional(),
        andar: z.number().int().optional(),
        elevador: z.boolean().optional(),
        mobiliado: z.boolean().default(false),

        caracteristicas: z.array(z.string()).default([]),
        condominio_lazer: z.array(z.string()).default([]),

        descricao: z.string().min(40, "Descrição muito curta: escreva 2 a 4 parágrafos."),

        fotos: z
          .array(
            z.object({
              src: image(),
              alt: z.string().min(3, "Toda foto precisa de alt descritivo (acessibilidade + SEO)."),
            })
          )
          .min(1, "Todo imóvel precisa de ao menos 1 foto — a foto[0] é a capa e a imagem de Open Graph."),

        // — Bloco de venda concluída (obrigatório quando status: vendido) —
        vendido_em: z.coerce.date().optional(),
        dias_para_vender: z.number().int().positive().optional(),
        depoimento_vendedor: z.string().optional(), // SÓ com autorização expressa do cliente

        registro_incorporacao: z.string().optional(),
        destaque_home: z.boolean().default(false),
        placeholder: z.boolean().default(false),
        publicado_em: z.coerce.date(),
        atualizado_em: z.coerce.date(),
      })
      .superRefine((dados, ctx) => {
        if (dados.status !== "pausado" && dados.autorizacao_escrita !== true) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ["autorizacao_escrita"],
            message:
              `TRAVA LEGAL — imóvel ${dados.ref}: status "${dados.status}" é publicável, mas ` +
              `"autorizacao_escrita" não é true. Corretor só anuncia com contrato de mediação ou ` +
              `autorização escrita (Decreto 81.871/78, art. 5º). Assine a autorização e marque ` +
              `"autorizacao_escrita: true", ou mude para "status: pausado".`,
          });
        }
        if (dados.status === "vendido" && !dados.vendido_em) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ["vendido_em"],
            message:
              `TRAVA DE PROVA — imóvel ${dados.ref}: está como "vendido" sem "vendido_em". ` +
              `Case sem data não é prova, é alegação. Preencha a data de conclusão da venda.`,
          });
        }
      })
      // Default condicional: em vendidos o valor final é dado privado das partes.
      .transform((dados) => ({
        ...dados,
        exibir_valor: dados.exibir_valor ?? dados.status !== "vendido",
      })),
});

const condominios = defineCollection({
  loader: glob({ base: "./src/content/condominios", pattern: "**/[^_]*.md" }),
  schema: ({ image }) =>
    z.object({
      nome: z.string().min(2),
      bairro: z.string().min(2), // slug do bairro
      tipo: z.enum(["vertical", "horizontal", "vilagio"]),
      ano_entrega: z.number().int().optional(),
      numero_unidades: z.number().int().positive().optional(),
      tipologias: z.array(z.string()).default([]),
      faixa_preco_min: z.number().int().positive().optional(),
      faixa_preco_max: z.number().int().positive().optional(),
      lazer: z.array(z.string()).default([]),
      descricao: z.string().min(40),
      tempo_medio_venda_dias: z.number().int().positive().optional(),
      faq: z
        .array(z.object({ pergunta: z.string().min(5), resposta: z.string().min(20) }))
        .default([]),
      foto_capa: image().optional(),
      // Posição do ponto no mapa do território (percentual do viewBox 0–100).
      mapa_x: z.number().min(0).max(100).optional(),
      mapa_y: z.number().min(0).max(100).optional(),
      placeholder: z.boolean().default(false),
      atualizado_em: z.coerce.date(),
    }),
});

const bairros = defineCollection({
  loader: glob({ base: "./src/content/bairros", pattern: "**/[^_]*.md" }),
  schema: ({ image }) =>
    z.object({
      nome: z.string().min(2),
      camada: z.enum(["nucleo", "faixa-alta", "alto-padrao"]),
      descricao: z.string().min(40),
      pontos_de_interesse: z.array(z.string()).default([]),
      faq: z
        .array(z.object({ pergunta: z.string().min(5), resposta: z.string().min(20) }))
        .default([]),
      foto_capa: image().optional(),
      placeholder: z.boolean().default(false),
      atualizado_em: z.coerce.date(),
    }),
});

export const collections = { imoveis, condominios, bairros };
