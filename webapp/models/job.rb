require 'csv'

class Job

  include Mongoid::Document
  include Mongoid::Timestamps
  attr_accessor :query
  belongs_to :account, :dependent => :nullify
  embeds_many :genes, :cascade_callbacks => true

  field :completed,     :type => Boolean, :default => false
  field :valid,         :type => Boolean, :default => false
  field :description,   :type => String
  field :email,         :type => Boolean, :default => false
  field :time,          :type => Integer
  field :bind_proteins, :type => Array

  validates_presence_of :query, :if => :query_required
  validates_presence_of :completed
  validates_presence_of :email
  validates_presence_of :description
  validates_length_of   :description, :within => 5..256

  def self.find_by_id(id)
    find(id) rescue nil
  end

  def to_csv(options = {})
    CSV.generate(options) do |csv|
      csv << %w[species gene_id gene_name transcript_id transcript_name] + self.bind_proteins
      genes.each do |gene|
        gene.transcripts.each do |trans|
          csv << [gene.species, gene.converted_id, gene.name, trans.converted_id, trans.name] + trans.matches.map { |x| x ? 'x' : '' }
        end
      end
    end
  end

  def dataset_json
    dataset = [['Proteins', 'Occurrences']]
    bind_proteins.each { |prot| dataset << [prot, 0] }
    genes.each do |gene|
      gene.transcripts.each do |trans|
        trans.matches.each_with_index do |match, i|
          if match
            dataset[i + 1][1] += 1
          end
        end
      end
    end
    dataset.to_json
  end

  private
  def query_required
    return !self.completed
  end

end
