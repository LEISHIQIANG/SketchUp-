# view_hotkeys_ahk.rb
# 两态切换：白膜 ⇄ 贴图（每次都强制关闭 X 光）

module AutoViewHotkeys
  extend self

  @@view_index  = -1
  @@style_state = 0 # 0=白膜, 1=贴图

  def toggle_perspective
    m = Sketchup.active_model or return
    v = m.active_view
    cam = v.camera
    cam.perspective = !cam.perspective?
    Sketchup.status_text = "已切换：#{cam.perspective? ? "透视视图" : "正交视图"}"
    v.invalidate
  end

  def cycle_views
    m = Sketchup.active_model or return
    v = m.active_view
    cam = v.camera
    @@view_index = (@@view_index + 1) % 5
    names   = ["前", "后", "左", "右", "上"]
    actions = ["viewFront:", "viewBack:", "viewLeft:", "viewRight:", "viewTop:"]
    cam.perspective = false
    Sketchup.send_action(actions[@@view_index])
    Sketchup.status_text = "已切换：#{names[@@view_index]}视图（正交）"
    v.invalidate
  end

  def cycle_styles
    m = Sketchup.active_model or return
    v = m.active_view
    opts = m.rendering_options

    ensure_xray_off!(opts)

    if @@style_state == 0
      apply_monochrome!(opts) # 白膜（你提供：RenderMode=5, Texture=true）
      @@style_state = 1
      msg = "单色模式（白膜）"
    else
      apply_textured!(opts)   # 贴图（你环境稳定：RenderMode=2, Texture=true）
      @@style_state = 0
      msg = "贴图模式"
    end

    Sketchup.status_text = "已切换：#{msg}"
    v.invalidate
  end

  # ————— 辅助 —————

  def ensure_xray_off!(opts)
    if opts["ModelTransparency"]
      Sketchup.send_action("viewXRay:") # toggle -> 关
    end
    opts["ModelTransparency"] = false
  end

  def apply_monochrome!(opts)
    opts["RenderMode"] = 5
    opts["Texture"]    = true
    # 如需更“纯白”，可解注以下两行：
    # opts["FaceFrontColor"] = Sketchup::Color.new(255, 255, 255)
    # opts["FaceBackColor"]  = Sketchup::Color.new(255, 255, 255)
  end

  def apply_textured!(opts)
    opts["RenderMode"] = 2
    opts["Texture"]    = true
    # 同步一次系统命令，避免风格残留
    Sketchup.send_action("viewShadedWithTextures:")
  end
end

unless file_loaded?(__FILE__)
  menu = UI.menu('Plugins')
  submenu = menu.add_submenu('视图快捷键')

  submenu.add_item('测试-透视切换') { AutoViewHotkeys.toggle_perspective }
  submenu.add_item('测试-视图循环') { AutoViewHotkeys.cycle_views }
  submenu.add_item('测试-样式循环') { AutoViewHotkeys.cycle_styles }

  file_loaded(__FILE__)
  puts "✅ 视图快捷键已加载"
end