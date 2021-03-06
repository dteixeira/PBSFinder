module Pbs
  module Analyzer
    # Analyzes NCBI IDs and retrieves basic information about them.
    class Ncbi
      def initialize(helper = nil)
        @helper = helper
      end

      # Processes a list of IDs and tries to identify/convert them.
      #
      # Input:
      #   - ids: array of strings (IDs)
      # Output:
      #   - array of GeneContainer objects
      def process_ids(ids)
        clean_ids(ids)
        genes = convert_ids(
          ids.select { |id| id =~ /^[A-Z]+[0-9]+$/ },
          @helper.config[:formats][:genna],
          [
            @helper.config[:formats][:engid],
            @helper.config[:formats][:ezgid]
          ]
        )
        genes.concat(convert_ids(
          ids.select { |id| id =~ /^[A-Z]+_[0-9]+$/ },
          @helper.config[:formats][:rseqr],
          [
            @helper.config[:formats][:engid],
            @helper.config[:formats][:ezgid]
          ]
        ))
        genes.concat(convert_from_geneid(ids.select { |id| id =~ /^[0-9]+$/ }))
        genes.uniq! { |gene| gene.gene_id }
        genes
      end

      # Finds protein binding sites for a list of genes.
      #
      # Input:
      #   - array of GeneContainer objects
      # Output:
      #   - array of GeneContainer objects
      def find_protein_binding_sites!(genes)
        if genes && genes.size > 0
          ids = find_transcript_ids(genes)
          process_transcript_ids(ids, genes)
        end
        genes
      end

      private

      def clean_ids(ids)
        ids.each_with_index do |id, i|
          ids[i] = id.split('.')[0]
        end
      end

      def find_transcript_ids(genes)
        ids = genes.map { |gene| gene.gene_id }
        converted = @helper.convert_ids(
          ids,
          @helper.config[:formats][:ezgid],
          [@helper.config[:formats][:rseqr]]
        )
        converted = converted.values
        converted.flatten!
        converted.select! { |trans| trans =~ /^(XM|NM)_[0-9]+/ }
        converted.uniq!
        converted
      end

      def build_transcripts(flat, genes)
        # Build each transcript.
        flat.each do |gb|
          t = gb.features.find { |f| f.feature == 'source' }
          taxon = t['db_xref'][0].split(':')[1] if t && t['db_xref']
          species = @helper.config[:taxons][taxon]
          id, name, utr5, utr3 = nil
          transcript_id = gb.locus.entry_id
          date = Date.parse(gb.locus.date) if gb.locus.date
          gb.each_cds do |cds|
            id = cds['db_xref'].find { |i| i =~ /GeneID/ }.split(':')[-1]
            name = (cds['gene'] || []).first
            loc = cds.locations.first
            seq = gb.naseq.upcase
            utr5 = seq[0...(loc.from - 1)]
            utr5 = nil if utr5.size == 0
            utr3 = seq[(loc.to)...seq.size]
            utr3 = nil if utr3.size == 0
            break
          end

          # If some data is missing ignore this document.
          unless species.to_s.empty? || id.to_s.empty? || transcript_id.to_s.empty? || !date || taxon.to_s.empty?
            gene = genes.find { |g| g.gene_id == id }
            if gene
              gene.species ||= species
              gene.name ||= name
              gene.taxon ||= taxon
              if gene.transcripts.size == 0 || transcript_id =~ /^NM_[0-9]+/
                gene.transcripts.delete_if { |k, v| k =~ /^XM_[0-9]+/ }
                gene.transcripts[transcript_id] = Container::Transcript.new(
                  transcript_id: transcript_id,
                  utr5: utr5,
                  utr3: utr3,
                  date: date
                )
              elsif !gene.transcripts.keys.find { |x| x =~ /^NM_[0-9]+/ }
                k, trans = gene.transcripts.first
                if date > trans.date
                  gene.transcripts[transcript_id] = Container::Transcript.new(
                    transcript_id: transcript_id,
                    utr5: utr5,
                    utr3: utr3,
                    date: date
                  )
                  gene.transcripts.delete(k)
                end
              end
            end
          end
        end
      rescue StandardError => e
        puts e.message, e.backtrace
      end

      def process_transcript_ids(ids, genes)
        return unless ids.size > 0

        # Request transcript GenBank pages.
        uri = URI::HTTP.build(
          host: @helper.config[:ncbi][:url],
          path: @helper.config[:ncbi][:fetch_path],
          query: URI.encode_www_form(
            @helper.config[:ncbi][:parameters].merge(@helper.config[:ncbi][:parameter_id] => ids.join(',')
          )
        ))
        flat = nil
        begin
          flat = Bio::FlatFile.open_uri(uri)
        rescue StandardError => e
          puts e.message, e.backtrace
          retry
        end
        build_transcripts(flat, genes)
      end

      def convert_ids(ids, input, output)
        return [] unless ids.size > 0
        genes = []
        ensembl = []
        converted_ids = @helper.convert_ids(ids, input, output)
        converted_ids.each do |id, values|
          gene = Container::Gene.new(original_id: id)
          converted = values.find { |x| x }
          if converted
            if converted =~ /^[0-9]+$/
              gene.gene_id = converted
              gene.type = :ncbi
              genes << gene
            else
              gene.gene_id = converted
              ensembl << gene
            end
          end
        end
        @helper.determine_ensembl_species!(ensembl)
        genes.concat(ensembl)
        genes
      end

      def convert_from_geneid(ids)
        return [] unless ids.size > 0
        genes = []
        ensembl = []
        converted_ids = @helper.convert_ids(
          ids,
          @helper.config[:formats][:ezgid],
          [@helper.config[:formats][:engid]]
        )
        converted_ids.each do |id, values|
          gene = Container::Gene.new(original_id: id)
          converted = values.find { |x| x }
          if converted
            gene.gene_id = converted
            ensembl << gene
          else
            gene.gene_id = id
            gene.type = :ncbi
            genes << gene
          end
        end
        @helper.determine_ensembl_species!(ensembl)
        genes.concat(ensembl)
        genes
      end
    end
  end
end
