class MeanImputer < Imputer
  def impute!(array)
    mean = array.compact
    return array if mean.blank?
    mean = mean.sum / mean.length
    array.each_with_index do |current, index|
      array[index] = mean if need_imputation? current
    end
    array
  end
end