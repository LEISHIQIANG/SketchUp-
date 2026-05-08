# Encoding: UTF-8
require 'sketchup.rb'

module M_SelectSimilar_Percentage
  
  # ==========================================
  # 用户设置区域
  # ==========================================
  # 设置线性尺寸容差百分比 (0.02 代表 2%)
  TOLERANCE_PCT = 0.02 
  # ==========================================

  def self.get_comparison_data(entity)
    # 返回结构: { :type => Symbol, :values => Array }
    
    if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      # 1. 获取定义包围盒
      d_bounds = entity.definition.bounds
      
      # 2. 获取变换缩放系数
      tr = entity.transformation
      scale_x = Math.sqrt(tr.to_a[0]**2 + tr.to_a[1]**2 + tr.to_a[2]**2)
      scale_y = Math.sqrt(tr.to_a[4]**2 + tr.to_a[5]**2 + tr.to_a[6]**2)
      scale_z = Math.sqrt(tr.to_a[8]**2 + tr.to_a[9]**2 + tr.to_a[10]**2)
      
      # 3. 计算实际物理尺寸
      dims = [
        d_bounds.width * scale_x,
        d_bounds.height * scale_y,
        d_bounds.depth * scale_z
      ]
      
      # 返回排序后的尺寸 (线性尺寸)
      return { :type => :linear_3d, :values => dims.sort }
      
    elsif entity.is_a?(Sketchup::Face)
      # 面：返回 [面积, 周长]
      # 面积对应二维误差，周长对应一维误差
      return { :type => :face_metrics, :values => [entity.area, entity.outer_loop.edges.map(&:length).sum] }
      
    elsif entity.is_a?(Sketchup::Edge)
      # 线：返回 [长度]
      return { :type => :linear_1d, :values => [entity.length] }
    end
    
    return nil
  end

  # 判断数值是否在百分比范围内
  def self.is_within_tolerance?(base_val, target_val, is_area_value = false)
    # 计算允许的最小值和最大值
    if is_area_value
      # 如果是面积，容差需要是线性的平方
      # 0.98 * 0.98 = 0.9604, 1.02 * 1.02 = 1.0404
      min_factor = (1.0 - TOLERANCE_PCT) ** 2
      max_factor = (1.0 + TOLERANCE_PCT) ** 2
    else
      # 线性尺寸直接使用百分比
      min_factor = 1.0 - TOLERANCE_PCT
      max_factor = 1.0 + TOLERANCE_PCT
    end

    min_limit = base_val * min_factor
    max_limit = base_val * max_factor

    return target_val >= min_limit && target_val <= max_limit
  end

  def self.data_match?(source_data, target_data)
    return false if source_data.nil? || target_data.nil?
    return false if source_data[:type] != target_data[:type]
    
    s_vals = source_data[:values]
    t_vals = target_data[:values] # 已经是排序过的或者是对应的指标
    
    # 针对不同类型进行比对
    if source_data[:type] == :face_metrics
      # 面数据：[面积, 周长]
      # 索引0是面积 (使用平方容差)，索引1是周长 (使用线性容差)
      area_match = is_within_tolerance?(s_vals[0], t_vals[0], true) 
      perim_match = is_within_tolerance?(s_vals[1], t_vals[1], false)
      return area_match && perim_match
    else
      # 组/组件/线：全部是线性尺寸，逐个比对
      s_vals.each_with_index do |val, i|
        return false unless is_within_tolerance?(val, t_vals[i], false)
      end
      return true
    end
  end

  def self.run
    model = Sketchup.active_model
    sel = model.selection
    
    if sel.length != 1
      UI.messagebox("请先选择一个参考物体。")
      return
    end
    
    source_entity = sel[0]
    source_data = get_comparison_data(source_entity)
    
    if source_data.nil?
      UI.messagebox("不支持该类型。请选择组、组件、面或线。")
      return
    end
    
    # 获取上下文
    entities_to_search = model.active_entities
    new_selection = []
    
    model.start_operation("选择近似尺寸 (2%)", true)
    
    entities_to_search.each do |e|
      next unless e.class == source_entity.class
      next if e == source_entity
      
      target_data = get_comparison_data(e)
      
      if data_match?(source_data, target_data)
        new_selection << e
      end
    end
    
    sel.add(new_selection)
    
    count = new_selection.length
    # 状态栏显示结果和当前容差设定
    msg = "找到 #{count} 个近似物体 (容差: #{(TOLERANCE_PCT*100).to_i}%)."
    Sketchup.status_text = msg
    puts msg # 输出到控制台以便查看
    
    model.commit_operation
  end
  
  unless file_loaded?(__FILE__)
    UI.menu("Plugins").add_item("选择相似物体 ") {
      self.run
    }
    file_loaded(__FILE__)
  end

end