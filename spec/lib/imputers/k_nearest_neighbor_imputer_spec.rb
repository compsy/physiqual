require 'rails_helper'

require 'shared_examples_for_imputers'

module Imputers
  describe KNearestNeighborImputer do
    it_behaves_like 'an imputer'
  end
end
