module FontHelper
  # WHY: a letter the face lacks is drawn by the fallback named after it, so its width changes with that fallback, while a letter the face carries measures the same behind both.
  def font_fallbacks(faces, letters)
    page.evaluate_async_script(<<~JAVASCRIPT, faces, letters)
      const [ faces, letters, done ] = arguments;
      const context = document.createElement("canvas").getContext("2d");
      const width = (font, letter) => { context.font = font; return context.measureText(letter).width; };
      Promise.all(faces.map((face) => document.fonts.load(face, letters)))
        .then(() => done(faces.flatMap((face) => [ ...letters ]
          .filter((letter) => width(`${face}, monospace`, letter) !== width(`${face}, serif`, letter))
          .map((letter) => `${face} ${letter}`))), (error) => done(String(error)));
    JAVASCRIPT
  end
end

RSpec.configure do |config|
  config.include FontHelper, type: :system
end
