module Pbs
  # Manages the ID analysis' workflow.
  class Workflow
    attr_accessor :job

    def initialize(config, ids, job_id)
      @job_id = job_id
      @helper = Analyzer::Helper.new(config)
      @ncbi = Analyzer::Ncbi.new(@helper)
      @ensembl = Analyzer::Ensembl.new(@helper)
      @uniprot = Analyzer::Uniprot.new(@helper)
      @kegg = Analyzer::Kegg.new(@helper)
      @cluster = Analyzer::Cluster.new(@helper)
      @ids = prepare_ids(ids)
      @job = Container::Job.new
    end

    def save_job_analysis
      Database.save_job_analysis(@job, @job_id)
    end

    def start_job_analysis
      return @job unless @ids.size > 0

      # Benchmark analysis.
      bench = Benchmark.realtime do

        # Base analysis.
        start_base_analysis
        break unless @job.genes.size > 0
        start_base_dataset_analysis

        # UniProt analysis.
        start_base_uniprot_analysis
        start_advanced_uniprot_analysis

        # Kegg analysis.
        start_base_kegg_analysis

        # Clustering analysis.
        start_base_clustering_analysis
        start_advanced_clustering_analysis

        # Final stage.
        Analyzer::Dataset.create_invalid_genes!(@job, @ids)
      end
      if bench
        job.time = bench < 1 ? 1 : bench.to_i
      end
      @job
    end

    private

    def start_base_clustering_analysis
      if @cluster.clean_dataset!(@job)
        @cluster.cluster_proteins!(@job)
        @cluster.cluster_genes!(@job)
        @cluster.find_similarities!(@job)
      end
    rescue StandardError => e
      puts e.message, e.backtrace
    end

    def start_advanced_clustering_analysis
      @cluster.cluster_genes_quant!(@job)
    rescue StandardError => e
      puts e.message, e.backtrace
    end

    def start_base_dataset_analysis
      Analyzer::Dataset.build_own_proteins!(@job)
      Analyzer::Dataset.build_lists!(@job)
      Analyzer::Dataset.build_matches!(@job)
    end

    def start_base_kegg_analysis
      @kegg.find_kegg_pathways!(@job)
    end

    def start_base_uniprot_analysis
      @uniprot.find_uniprot_ids!(@job)
    end

    def start_advanced_uniprot_analysis
      @uniprot.find_uniprot_info!(@job)
    end

    def start_base_analysis
      # Identify genes.
      genes = @ensembl.process_ids(@ids).concat(@ncbi.process_ids(@ids))
      genes = Analyzer::Dataset.divide_genes(genes)

      # Find gene transcripts.
      @ncbi.find_protein_binding_sites!(genes[:ncbi])
      @ensembl.find_protein_binding_sites!(genes[:ensembl])

      # Find protein binding sites.
      genes = genes[:ncbi].concat(genes[:ensembl])
      genes.select! { |x| x.gene_id && x.transcripts.size > 0 }
      @helper.find_protein_binding_sites!(genes)
      @job.genes = genes
    end

    def prepare_ids(ids)
      ids = ids.split("\n").map! { |x| x.strip.upcase }
      ids.reject! { |x| x.empty? }
      ids.uniq!
      ids
    end
  end
end
