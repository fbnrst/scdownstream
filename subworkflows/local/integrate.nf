include { ADATA_TORDS         } from '../../modules/local/adata/tords'
include { SCVITOOLS_SCVI      } from '../../modules/local/scvitools/scvi'
include { SCVITOOLS_SCANVI    } from '../../modules/local/scvitools/scanvi'
include { INTEGRATION_HARMONY } from '../../modules/local/integration/harmony'
include { INTEGRATION_BBKNN   } from '../../modules/local/integration/bbknn'
include { SCANPY_COMBAT       } from '../../modules/local/scanpy/combat'
include { SEURAT_INTEGRATION  } from '../../modules/local/seurat/integration'
include { ADATA_READRDS       } from '../../modules/local/adata/readrds'

workflow INTEGRATE {
    take:
    ch_h5ad

    main:
    ch_versions = Channel.empty()
    ch_obs = Channel.empty()
    ch_obsm = Channel.empty()
    ch_layers = Channel.empty()
    ch_integrations = Channel.empty()

    ADATA_TORDS(ch_h5ad)
    ch_versions = ch_versions.mix(ADATA_TORDS.out.versions)
    ch_rds = ADATA_TORDS.out.rds

    methods = params.integration_methods.split(',').collect{it.trim().toLowerCase()}

    if (methods.contains('scvi') || methods.contains('scanvi')) {
        SCVITOOLS_SCVI(ch_h5ad.map{meta, h5ad -> [[id: 'scvi'], h5ad]})
        ch_versions = ch_versions.mix(SCVITOOLS_SCVI.out.versions)
        ch_integrations = ch_integrations.mix(SCVITOOLS_SCVI.out.h5ad)
        ch_obsm = ch_obsm.mix(SCVITOOLS_SCVI.out.obsm)

        if (methods.contains('scanvi')) {
            SCVITOOLS_SCANVI(ch_h5ad.map{meta, h5ad -> [[id: 'scanvi'], h5ad]},
                SCVITOOLS_SCVI.out.model.collect())
            ch_versions = ch_versions.mix(SCVITOOLS_SCANVI.out.versions)
            ch_integrations = ch_integrations.mix(SCVITOOLS_SCANVI.out.h5ad)
            ch_obs = ch_obs.mix(SCVITOOLS_SCANVI.out.obs)
            ch_obsm = ch_obsm.mix(SCVITOOLS_SCANVI.out.obsm)
        }
    }

    if (methods.contains('harmony')) {
        INTEGRATION_HARMONY(ch_h5ad.map{meta, h5ad -> [[id: 'harmony'], h5ad]})
        ch_versions = ch_versions.mix(INTEGRATION_HARMONY.out.versions)
        ch_integrations = ch_integrations.mix(INTEGRATION_HARMONY.out.h5ad)
        ch_obsm = ch_obsm.mix(INTEGRATION_HARMONY.out.obsm)
    }

    if (methods.contains('bbknn')) {
        INTEGRATION_BBKNN(ch_h5ad.map{meta, h5ad -> [[id: 'bbknn'], h5ad]})
        ch_versions = ch_versions.mix(INTEGRATION_BBKNN.out.versions)
        ch_integrations = ch_integrations.mix(INTEGRATION_BBKNN.out.h5ad)
    }

    if (methods.contains('combat')) {
        SCANPY_COMBAT(ch_h5ad.map{meta, h5ad -> [[id: 'combat'], h5ad]})
        ch_versions = ch_versions.mix(SCANPY_COMBAT.out.versions)
        ch_integrations = ch_integrations.mix(SCANPY_COMBAT.out.h5ad)
        ch_obsm = ch_obsm.mix(SCANPY_COMBAT.out.obsm)
        ch_layers = ch_layers.mix(SCANPY_COMBAT.out.layers)
    }

    if (methods.contains('seurat')) {
        SEURAT_INTEGRATION(ch_rds.map{meta, rds -> [[id: 'seurat'], rds]})
        ch_versions = ch_versions.mix(SEURAT_INTEGRATION.out.versions)
        ch_integrations = ch_integrations.mix(SEURAT_INTEGRATION.out.rds)
    }

    ch_integrations = ch_integrations
        .map{meta, file -> [meta + [integration: meta.id], file]}
        .branch{ meta, file ->
            rds: file.extension == 'rds'
            h5ad: file.extension == 'h5ad'
        }

    ADATA_READRDS(ch_integrations.rds)
    ch_versions = ch_versions.mix(ADATA_READRDS.out.versions)

    ch_integrations = ch_integrations.h5ad.mix(ADATA_READRDS.out.h5ad)
    ch_obsm = ch_obsm.mix(ADATA_READRDS.out.obsm)

    emit:
    integrations = ch_integrations
    obs = ch_obs
    obsm = ch_obsm
    layers = ch_layers

    versions = ch_versions
}
