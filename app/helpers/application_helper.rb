module ApplicationHelper
  IMAGES = Rails.root.join("app/assets/images")

  # Renders an SVG from app/assets/images into the document, rather than
  # linking it with image_tag.
  #
  # Worth doing only when CSS has to reach inside the file. An <img> is an
  # opaque document: no rule outside it can touch the shapes in it, so a hover
  # state that recolours one rect of a vector is impossible through image_tag.
  # That is the home button's case and currently the only one.
  #
  # The file is read on every render. It is 800 bytes off the OS page cache,
  # and the alternative -- a process-wide memo -- means editing the asset in
  # development shows nothing until a restart.
  #
  # `name` is a literal at every call site. Nothing user-supplied reaches it,
  # which is what makes joining it onto a path safe here.
  def inline_svg(name)
    svg = IMAGES.join(name).read

    # Decorative by definition: every caller is inside a link or button that
    # carries its own accessible name, and focusable="false" keeps the SVG out
    # of the tab order where a browser would otherwise put it.
    raw svg.sub("<svg ", %(<svg aria-hidden="true" focusable="false" ))
  end
end
