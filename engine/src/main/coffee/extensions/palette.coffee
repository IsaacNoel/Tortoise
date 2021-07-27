# (C) Uri Wilensky. https://github.com/NetLogo/Tortoise

{ exceptionFactory: exceptions } = require('util/exception')

SingleObjectExtensionPorter = require('../engine/core/world/singleobjectextensionporter')

Color = require('../engine/core/colormodel')
# MAIN FUNCTIONS #

#RGBList
validateRGB = (color) ->
  if(not isValidRGBList(color))
    throw exceptions.extension("Color must have a valid RGB list.")
  return

isValidRGBList = (color) ->
  valid = (true)
  color = toColorList(color)
  if(color.length < 3 or color.length > 4)
    return false
  valid = color.every((component) ->
    return typeof component is "number") and
    not color.some((component) ->
      return component < 0 or component > 255)
  return valid

extractRGB = (color, index) ->
  newList = toColorList(color)
  validateRGB(newList)
  return newList[index]

rgbUpdated = (color, value, index) ->
  color = toColorList(color)
  validateRGB(color)
  newList = color.slice()
  newList[index] = value
  return newList


#HSB
validateHSB = (color) ->
  if(not isValidHSBList(color))
    throw exceptions.extension("Color must be a valid HSB list.")
  return

isValidHSBList = (color) -> # must be a list upon import
  valid = true
  if(typeof color is "number")
    throw exeptions.extension("Input must be an HSB list for scale-gradient-hsb.")
  if(color.length is not 3)
    return false
  valid = color.every((component) ->
    return typeof component is "number")
  if(color[0] > 360 or color[0] < 0)
    return false
  for x in [1..2]
    if(color[x] > 100 or color[x] < 0)
      return false
  return valid

extractHSB = (color, index) ->
  newList = toColorList(color)
  validateRGB(newList)
  newList = Color.rgbToHSB(newList[0],newList[1],newList[2])
  return newList[index]

hsbUpdated = (color, value, index) ->
  newList = toColorList(color)
  validateRGB(newList)
  alpha = 255
  re_add = false
  if(newList.length is 4)
    alpha = newList[3]
    readd = true
  newList = Color.rgbToHSB(newList[0],newList[1],newList[2])
  newList[index] = value
  newList = Color.hsbToRGB(newList[0],newList[1],newList[2])
  if(readd is true)
    newList[3] = alpha
  return newList

#GRADIENTS AND COLOR SCHEMES
getIndex = (number, min, max, colorListLength, SIZE) ->
  perc = 0
  if(min > max)
    if (number < max)
      perc = 1
    else if (number > min)
      perc = 0
    else
      perc = (min - number) / (min - max)
  else
    if(number > max)
      perc = 1
    else if(number < min)
      perc = 0
    else
      if(max is min)
        perc = 0
      else
       perc = (number - min) / (max - min)
  index = 0
  gradientArray = [[],[]]
  if (colorListLength < 3)
    index = Math.round(perc * (SIZE - 1))
  else
    index = Math.round(perc * ( (SIZE - 1) + (SIZE) * (colorListLength - 2) ))
  return index

colorHSBArray = (startColor, endColor, width) -> # input colors in HSB form
  width--
  inc = startColor.slice()

  if (endColor[0] > startColor[0])
    if (startColor[0] + 360.0 - endColor[0] < endColor[0] - startColor[0])
      inc[0] = (endColor[0] - (startColor[0] + 360.0)) / width
    else
      inc[0] = (endColor[0] - startColor[0]) / width
  else
    if(endColor[0] + 360.0 - startColor[0] < startColor[0] - endColor[0])
      inc[0] = (endColor[0] + 360.0 - startColor[0]) / width
    else
      inc[0] = (endColor[0] - startColor[0]) / width
  inc[1] = (endColor[1] - startColor[1]) / width
  inc[2] = (endColor[2] - startColor[2]) / width
  width++

  gradientHSBarray = [[],[]]
  gradientHSBarray[0] = startColor.slice()
  i = 1
  for i in [1...width]
    gradientHSBarray[i] = startColor.slice() # just to avoid errors – all values will be over written
    for j in [0..2]
      gradientHSBarray[i][j] = gradientHSBarray[i - 1][j] + inc[j]
      if(j > 0)
        gradientHSBarray[i][j] = Math.min(100, Math.max(0, gradientHSBarray[i][j]))
      else
        if(gradientHSBarray[i][j] >= 360)
          gradientHSBarray[i][j] -= 360
        if(gradientHSBarray[i][j] < 0)
          gradientHSBarray[i][j] += 360

  return gradientHSBarray

colorRGBArray = (startColor, endColor, width) ->
  width--
  inc = startColor.slice()
  inc[0] = (endColor[0] - startColor[0]) / width
  inc[1] = (endColor[1] - startColor[1]) / width
  inc[2] = (endColor[2] - startColor[2]) / width
  width++

  gradientRGBArray = [[],[]]
  gradientRGBArray[0] = startColor.slice()

  for i in [1...width]
    gradientRGBArray[i] = startColor.slice() # just to avoid errors – all values will be over written
    for j in [0..2]
      gradientRGBArray[i][j] = gradientRGBArray[i - 1][j] + inc[j]
      gradientRGBArray[i][j] = Math.min(255, Math.max(0, gradientRGBArray[i][j]))
  return gradientRGBArray


#MISC
modDouble = (number, limit) ->
  while number > limit
    number -= limit
  while number < 0
    number += limit
  return number

toColorList = (color) ->
  if(typeof color is "number")
    color = Color.colorToRGB(color)
    if(color.length is 4) # sometimes gives an alpha of 0
      color.pop()
  return color

#CLASSES FOR COLOR SCHEMES
class ColorSchemes
  @maxColorScheme = 12
  @schemeTypes = {"Sequential", "Divergent", "Qualitative"}

  @getRGBArray: (schemeName, legendName, legendSize) ->
    if (arguments.length is 1)
      colorScheme = [[[[]]]]
      if schemeName is "Sequential"
        selectedClass = Sequential.class
      else if schemeName is "Divergent"
        selectedClass = Divergent.class
      else if schemeName is "Qualitative"
        selectedClass = Qualitative.class
      else
        throw exceptions.exception("1 Your Scheme Type name was " + schemeName + " your argument can only be : Sequential, Divergent or Qualitative")
      try
        fields = selectedClass.getDeclaredFields()
        for i in [0 ... fields.length]
          colorScheme[i] = fields[i].get(null)
      catch e
        throw exceptions.extension("the currently executing method does not have access to the definition of the specified field")
      return colorScheme
    else if (arguments.length is 2)
      colorScheme = [[[],[]],[[],[]]]
      if schemeName is "org.nlogo.render.Sequential" or schemeName is "Sequential"
        try
          colorScheme = Sequential.getScheme(legendName)
        catch e
          throw exceptions.extension(e)
      else if schemeName is "org.nlogo.render.Divergent" or schemeName is "Divergent"
        try
          colorScheme = Divergent.getScheme(legendName)
        catch e
          throw exceptions.extension(e)
      else if schemeName is "org.nlogo.render.Qualitative" or schemeName is "Qualitative"
        try
          colorScheme = Qualitative.getScheme(legendName)
        catch e
          throw exceptions.extension(e)
      else
        extension.exception("1 Your Scheme Type name was " + schemeName + " your argument can only be: Sequential, Divergent or Qualitative.")
      return colorScheme
    else if (arguments.length is 3)
      colorScheme = [[[],[]],[[],[]]]
      colorLegend = [[],[]]
      if legendSize < 3
        throw exceptions.extension("The minimum size of a color class is 3, but your third argument is " + legendSize)

      colorScheme = ColorSchemes.getRGBArray(schemeName, legendName)

      i = 0
      while i < colorScheme.length and (colorScheme[i].length isnt legendSize)
        i++

      if i < colorScheme.length
        colorLegend = [[],[]]
        colorLegend = colorScheme[i]
      else
        colorLegend = null
      return colorLegend


  @getColorArray: (schemeTypeName, colorSchemeName, colorSchemeSize) ->
    chosenColorLegend = []
    colorArray = [[],[]]
    colorArray = getRGBArray(schemeTypeName, colorSchemeName, colorSchemeSize)

    if colorSchemeSize < 3
      throw exceptions.extension("The minimum size of a color class is 3, but your third argument is " + colorSchemeSize)
    for i in [0...colorArray.legnth]
      chosenColorLegend[i] = [ colorArray[i][0], colorArray[i][1], colorArray[i][2] ]
    return chosenColorLegend

  @getIntArray: (schemeTypeName, colorSchemeName, colorSchemeSize) ->
    if colorSchemeSize < 3
      throw exceptions.extension("The minimum size of a color class is 3, but your third argument is " + colorSchemeSize)

    colorInt = []
    colorArray = getRGBArray(schemeTypeName, colorSchemeName, colorSchemeSize)

    for i in [0 ... colorArray.length]
      colorInt[i] = (colorArray[i][0] << 16) | (colorArray[i][1] << 8 ) | (colorArray[i][2])
    return colorInt

  @getschemeTypes: () ->
    return schemeTypes

  @getMaximumLegendSize: (schemeType) ->
    colorschemes = getRGBArray(schemeType)
    max = 0
    for i in [0...colorschemes.legnth - 1]
      max = Math.max(colorschemes[i].length, colorschemes[i + 1].length)
    return max + 2

class Divergent extends ColorSchemes
  @getScheme: (legendName) ->
    if legendName is "PuOr"
      return PuOr
    else if legendName is "Spectral"
      return Spectral
    else if legendName is "RdYlBu"
      return RdYlBu
    else if legendName is "RdBu"
      return RdBu
    else if legendName is "RdGy"
      return RdGy
    else if legendName is "RdYlGn"
      return RdYlGn
    else if legendName is "PRGn"
      return PRGn
    else if legendName is "PiYG"
      return PiYG
    else if legendName is "BrBG"
      return BrBG

  PuOr = [
    [ [  241 ,  163  ,  64],
    [  247  ,  247 , 247],
    [  153  ,  142  ,  195  ]  ],
    [  [  230  ,  97  ,  1  ]  ,
    [  253  ,  184  ,  99]  ,
    [  178  ,  171  ,  210 ]  ,
    [  94  ,  60  ,  153  ]  ],
    [  [  230  ,  97  ,  1  ]  ,
    [  253  ,  184  ,  99  ]  ,
    [  247  ,  247  ,  247  ]  ,
    [  178  ,  171  ,  210  ]  ,
    [  94  ,  60  ,  153  ]  ],
    [  [  179  ,  88  ,  6  ]  ,
    [  241  ,  163  ,  64  ]  ,
    [  254  ,  224  ,  182  ]  ,
    [  216  ,  218  ,  235  ]  ,
    [  153  ,  142  ,  195  ]  ,
    [  84  ,  39  ,  136  ]  ],
    [  [  179  ,  88  ,  6  ]  ,
    [  241  ,  163  ,  64  ]  ,
    [  254  ,  224  ,  182  ]  ,
    [  247  ,  247  ,  247  ]  ,
    [  216  ,  218  ,  235  ]  ,
    [  153  ,  142  ,  195  ]  ,
    [  84  ,  39  ,  136  ]  ],
    [  [  179  ,  88  ,  6  ]  ,
    [  224  ,  130  ,  20  ]  ,
    [  253  ,  184  ,  99  ]  ,
    [  254  ,  224  ,  182  ]  ,
    [  216  ,  218  ,  235  ]  ,
    [  178  ,  171  ,  210  ]  ,
    [  128  ,  115  ,  172  ]  ,
    [  84  ,  39  ,  136  ]  ],
    [  [  179  ,  88  ,  6  ]  ,
    [  224  ,  130  ,  20  ]  ,
    [  253  ,  184  ,  99  ]  ,
    [  254  ,  224  ,  182  ]  ,
    [  247  ,  247  ,  247  ]  ,
    [  216  ,  218  ,  235  ]  ,
    [  178  ,  171  ,  210  ]  ,
    [  128  ,  115  ,  172  ]  ,
    [  84  ,  39  ,  136  ]  ],
    [  [  127  ,  59  ,  8  ]  ,
    [  179  ,  88  ,  6  ]  ,
    [  224  ,  130  ,  20  ]  ,
    [  253  ,  184  ,  99  ]  ,
    [  254  ,  224  ,  182  ]  ,
    [  216  ,  218  ,  235  ]  ,
    [  178  ,  171  ,  210  ]  ,
    [  128  ,  115  ,  172  ]  ,
    [  84  ,  39  ,  136  ]  ,
    [  45  ,  0  ,  75  ]  ],
    [  [  127  ,  59  ,  8  ]  ,
    [  179  ,  88  ,  6  ]  ,
    [  224  ,  130  ,  20  ]  ,
    [  253  ,  184  ,  99  ]  ,
    [  254  ,  224  ,  182  ]  ,
    [  247  ,  247  ,  247  ]  ,
    [  216  ,  218  ,  235  ]  ,
    [  178  ,  171  ,  210  ]  ,
    [  128  ,  115  ,  172  ]  ,
    [  84  ,  39  ,  136  ]  ,
    [  45  ,  0  ,  75  ]  ] ]

  Spectral = [
    [  [  252  ,  141  ,  89  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  153  ,  213  ,  148  ]  ],
    [  [  215  ,  25  ,  28  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  171  ,  221  ,  164  ]  ,
      [  43  ,  131  ,  186  ]  ],
    [  [  215  ,  25  ,  28  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  171  ,  221  ,  164  ]  ,
      [  43  ,  131  ,  186  ]  ],
    [  [  213  ,  62  ,  79  ]  ,
      [  252  ,  141  ,  89  ]  ,
      [  254  ,  224  ,  139  ]  ,
      [  230  ,  245  ,  152  ]  ,
      [  153  ,  213  ,  148  ]  ,
      [  50  ,  136  ,  189  ]  ],
    [  [  213  ,  62  ,  79  ]  ,
      [  252  ,  141  ,  89  ]  ,
      [  254  ,  224  ,  139  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  230  ,  245  ,  152  ]  ,
      [  153  ,  213  ,  148  ]  ,
      [  50  ,  136  ,  189  ]  ],
    [  [  213  ,  62  ,  79  ]  ,
      [  244  ,  109  ,  67  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  254  ,  224  ,  139  ]  ,
      [  230  ,  245  ,  152  ]  ,
      [  171  ,  221  ,  164  ]  ,
      [  102  ,  194  ,  165  ]  ,
      [  50  ,  136  ,  189  ]  ],
    [  [  213  ,  62  ,  79  ]  ,
      [  244  ,  109  ,  67  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  254  ,  224  ,  139  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  230  ,  245  ,  152  ]  ,
      [  171  ,  221  ,  164  ]  ,
      [  102  ,  194  ,  165  ]  ,
      [  50  ,  136  ,  189  ]  ],
    [  [  158  ,  1  ,  66  ]  ,
      [  213  ,  62  ,  79  ]  ,
      [  244  ,  109  ,  67  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  254  ,  224  ,  139  ]  ,
      [  230  ,  245  ,  152  ]  ,
      [  171  ,  221  ,  164  ]  ,
      [  102  ,  194  ,  165  ]  ,
      [  50  ,  136  ,  189  ]  ,
      [  94  ,  79  ,  162  ]  ],
    [  [  158  ,  1  ,  66  ]  ,
      [  213  ,  62  ,  79  ]  ,
      [  244  ,  109  ,  67  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  254  ,  224  ,  139  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  230  ,  245  ,  152  ]  ,
      [  171  ,  221  ,  164  ]  ,
      [  102  ,  194  ,  165  ]  ,
      [  50  ,  136  ,  189  ]  ,
      [  94  ,  79  ,  162  ]  ]]

  RdYlBu = [
    [  [  252  ,  141  ,  89  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  145  ,  191  ,  219  ]  ],
    [  [  215  ,  25  ,  28  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  171  ,  217  ,  233  ]  ,
      [  44  ,  123  ,  182  ]  ],
    [  [  215  ,  25  ,  28  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  171  ,  217  ,  233  ]  ,
      [  44  ,  123  ,  182  ]  ],
    [  [  215  ,  48  ,  39  ]  ,
      [  252  ,  141  ,  89  ]  ,
      [  254  ,  224  ,  144  ]  ,
      [  224  ,  243  ,  248  ]  ,
      [  145  ,  191  ,  219  ]  ,
      [  69  ,  117  ,  180  ]  ],
    [  [  215  ,  48  ,  39  ]  ,
      [  252  ,  141  ,  89  ]  ,
      [  254  ,  224  ,  144  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  224  ,  243  ,  248  ]  ,
      [  145  ,  191  ,  219  ]  ,
      [  69  ,  117  ,  180  ]  ],
    [  [  215  ,  48  ,  39  ]  ,
      [  244  ,  109  ,  67  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  254  ,  224  ,  144  ]  ,
      [  224  ,  243  ,  248  ]  ,
      [  171  ,  217  ,  233  ]  ,
      [  116  ,  173  ,  209  ]  ,
      [  69  ,  117  ,  180  ]  ],
    [  [  215  ,  48  ,  39  ]  ,
      [  244  ,  109  ,  67  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  254  ,  224  ,  144  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  224  ,  243  ,  248  ]  ,
      [  171  ,  217  ,  233  ]  ,
      [  116  ,  173  ,  209  ]  ,
      [  69  ,  117  ,  180  ]  ],
    [  [  165  ,  0  ,  38  ]  ,
      [  215  ,  48  ,  39  ]  ,
      [  244  ,  109  ,  67  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  254  ,  224  ,  144  ]  ,
      [  224  ,  243  ,  248  ]  ,
      [  171  ,  217  ,  233  ]  ,
      [  116  ,  173  ,  209  ]  ,
      [  69  ,  117  ,  180  ]  ,
      [  49  ,  54  ,  149  ]  ],
    [  [  165  ,  0  ,  38  ]  ,
      [  215  ,  48  ,  39  ]  ,
      [  244  ,  109  ,  67  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  254  ,  224  ,  144  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  224  ,  243  ,  248  ]  ,
      [  171  ,  217  ,  233  ]  ,
      [  116  ,  173  ,  209  ]  ,
      [  69  ,  117  ,  180  ]  ,
      [  49  ,  54  ,  149  ]  ]]

  RdBu = [
    [  [  239  ,  138  ,  98  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  103  ,  169  ,  207  ]  ],
    [  [  202  ,  0  ,  32  ]  ,
      [  244  ,  165  ,  130  ]  ,
      [  146  ,  197  ,  222  ]  ,
      [  5  ,  113  ,  176  ]  ],
    [  [  202  ,  0  ,  32  ]  ,
      [  244  ,  165  ,  130  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  146  ,  197  ,  222  ]  ,
      [  5  ,  113  ,  176  ]  ],
    [  [  178  ,  24  ,  43  ]  ,
      [  239  ,  138  ,  98  ]  ,
      [  253  ,  219  ,  199  ]  ,
      [  209  ,  229  ,  240  ]  ,
      [  103  ,  169  ,  207  ]  ,
      [  33  ,  102  ,  172  ]  ],
    [  [  178  ,  24  ,  43  ]  ,
      [  239  ,  138  ,  98  ]  ,
      [  253  ,  219  ,  199  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  209  ,  229  ,  240  ]  ,
      [  103  ,  169  ,  207  ]  ,
      [  33  ,  102  ,  172  ]  ],
    [  [  178  ,  24  ,  43  ]  ,
      [  214  ,  96  ,  77  ]  ,
      [  244  ,  165  ,  130  ]  ,
      [  253  ,  219  ,  199  ]  ,
      [  209  ,  229  ,  240  ]  ,
      [  146  ,  197  ,  222  ]  ,
      [  67  ,  147  ,  195  ]  ,
      [  33  ,  102  ,  172  ]  ],
    [  [  178  ,  24  ,  43  ]  ,
      [  214  ,  96  ,  77  ]  ,
      [  244  ,  165  ,  130  ]  ,
      [  253  ,  219  ,  199  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  209  ,  229  ,  240  ]  ,
      [  146  ,  197  ,  222  ]  ,
      [  67  ,  147  ,  195  ]  ,
      [  33  ,  102  ,  172  ]  ],
    [  [  103  ,  0  ,  31  ]  ,
      [  178  ,  24  ,  43  ]  ,
      [  214  ,  96  ,  77  ]  ,
      [  244  ,  165  ,  130  ]  ,
      [  253  ,  219  ,  199  ]  ,
      [  209  ,  229  ,  240  ]  ,
      [  146  ,  197  ,  222  ]  ,
      [  67  ,  147  ,  195  ]  ,
      [  33  ,  102  ,  172  ]  ,
      [  5  ,  48  ,  97  ]  ],
    [  [  103  ,  0  ,  31  ]  ,
      [  178  ,  24  ,  43  ]  ,
      [  214  ,  96  ,  77  ]  ,
      [  244  ,  165  ,  130  ]  ,
      [  253  ,  219  ,  199  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  209  ,  229  ,  240  ]  ,
      [  146  ,  197  ,  222  ]  ,
      [  67  ,  147  ,  195  ]  ,
      [  33  ,  102  ,  172  ]  ,
      [  5  ,  48  ,  97  ]  ]]

  RdGy = [
    [  [  239  ,  138  ,  98  ]  ,
      [  255  ,  255  ,  255  ]  ,
      [  153  ,  153  ,  153  ]  ],
    [  [  202  ,  0  ,  32  ]  ,
      [  244  ,  165  ,  130  ]  ,
      [  186  ,  186  ,  186  ]  ,
      [  64  ,  64  ,  64  ]  ],
    [  [  202  ,  0  ,  32  ]  ,
      [  244  ,  165  ,  130  ]  ,
      [  255  ,  255  ,  255  ]  ,
      [  186  ,  186  ,  186  ]  ,
      [  64  ,  64  ,  64  ]  ],
    [  [  178  ,  24  ,  43  ]  ,
      [  239  ,  138  ,  98  ]  ,
      [  253  ,  219  ,  199  ]  ,
      [  224  ,  224  ,  224  ]  ,
      [  153  ,  153  ,  153  ]  ,
      [  77  ,  77  ,  77  ]  ],
    [  [  178  ,  24  ,  43  ]  ,
      [  239  ,  138  ,  98  ]  ,
      [  253  ,  219  ,  199  ]  ,
      [  255  ,  255  ,  255  ]  ,
      [  224  ,  224  ,  224  ]  ,
      [  153  ,  153  ,  153  ]  ,
      [  77  ,  77  ,  77  ]  ],
    [  [  178  ,  24  ,  43  ]  ,
      [  214  ,  96  ,  77  ]  ,
      [  244  ,  165  ,  130  ]  ,
      [  253  ,  219  ,  199  ]  ,
      [  224  ,  224  ,  224  ]  ,
      [  186  ,  186  ,  186  ]  ,
      [  135  ,  135  ,  135  ]  ,
      [  77  ,  77  ,  77  ]  ],
    [  [  178  ,  24  ,  43  ]  ,
      [  214  ,  96  ,  77  ]  ,
      [  244  ,  165  ,  130  ]  ,
      [  253  ,  219  ,  199  ]  ,
      [  255  ,  255  ,  255  ]  ,
      [  224  ,  224  ,  224  ]  ,
      [  186  ,  186  ,  186  ]  ,
      [  135  ,  135  ,  135  ]  ,
      [  77  ,  77  ,  77  ]  ],
    [  [  103  ,  0  ,  31  ]  ,
      [  178  ,  24  ,  43  ]  ,
      [  214  ,  96  ,  77  ]  ,
      [  244  ,  165  ,  130  ]  ,
      [  253  ,  219  ,  199  ]  ,
      [  224  ,  224  ,  224  ]  ,
      [  186  ,  186  ,  186  ]  ,
      [  135  ,  135  ,  135  ]  ,
      [  77  ,  77  ,  77  ]  ,
      [  26  ,  26  ,  26  ]  ],
    [  [  103  ,  0  ,  31  ]  ,
      [  178  ,  24  ,  43  ]  ,
      [  214  ,  96  ,  77  ]  ,
      [  244  ,  165  ,  130  ]  ,
      [  253  ,  219  ,  199  ]  ,
      [  255  ,  255  ,  255  ]  ,
      [  224  ,  224  ,  224  ]  ,
      [  186  ,  186  ,  186  ]  ,
      [  135  ,  135  ,  135  ]  ,
      [  77  ,  77  ,  77  ]  ,
      [  26  ,  26  ,  26  ]  ]]

  RdYlGn = [
    [  [  252  ,  141  ,  89  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  145  ,  207  ,  96  ]  ],
    [  [  215  ,  25  ,  28  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  166  ,  217  ,  106  ]  ,
      [  26  ,  150  ,  65  ]  ],
    [  [  215  ,  25  ,  28  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  166  ,  217  ,  106  ]  ,
      [  26  ,  150  ,  65  ]  ],
    [  [  215  ,  48  ,  39  ]  ,
      [  252  ,  141  ,  89  ]  ,
      [  254  ,  224  ,  139  ]  ,
      [  217  ,  239  ,  139  ]  ,
      [  145  ,  207  ,  96  ]  ,
      [  26  ,  152  ,  80  ]  ],
    [  [  215  ,  48  ,  39  ]  ,
      [  252  ,  141  ,  89  ]  ,
      [  254  ,  224  ,  139  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  217  ,  239  ,  139  ]  ,
      [  145  ,  207  ,  96  ]  ,
      [  26  ,  152  ,  80  ]  ],
    [  [  215  ,  48  ,  39  ]  ,
      [  244  ,  109  ,  67  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  254  ,  224  ,  139  ]  ,
      [  217  ,  239  ,  139  ]  ,
      [  166  ,  217  ,  106  ]  ,
      [  102  ,  189  ,  99  ]  ,
      [  26  ,  152  ,  80  ]  ],
    [  [  215  ,  48  ,  39  ]  ,
      [  244  ,  109  ,  67  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  254  ,  224  ,  139  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  217  ,  239  ,  139  ]  ,
      [  166  ,  217  ,  106  ]  ,
      [  102  ,  189  ,  99  ]  ,
      [  26  ,  152  ,  80  ]  ],
    [  [  165  ,  0  ,  38  ]  ,
      [  215  ,  48  ,  39  ]  ,
      [  244  ,  109  ,  67  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  254  ,  224  ,  139  ]  ,
      [  217  ,  239  ,  139  ]  ,
      [  166  ,  217  ,  106  ]  ,
      [  102  ,  189  ,  99  ]  ,
      [  26  ,  152  ,  80  ]  ,
      [  0  ,  104  ,  55  ]  ],
    [  [  165  ,  0  ,  38  ]  ,
      [  215  ,  48  ,  39  ]  ,
      [  244  ,  109  ,  67  ]  ,
      [  253  ,  174  ,  97  ]  ,
      [  254  ,  224  ,  139  ]  ,
      [  255  ,  255  ,  191  ]  ,
      [  217  ,  239  ,  139  ]  ,
      [  166  ,  217  ,  106  ]  ,
      [  102  ,  189  ,  99  ]  ,
      [  26  ,  152  ,  80  ]  ,
      [  0  ,  104  ,  55  ]  ]]

  PRGn = [
    [  [  175  ,  141  ,  195  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  127  ,  191  ,  123  ]  ],
    [  [  123  ,  50  ,  148  ]  ,
      [  194  ,  165  ,  207  ]  ,
      [  166  ,  219  ,  160  ]  ,
      [  0  ,  136  ,  55  ]  ],
    [  [  123  ,  50  ,  148  ]  ,
      [  194  ,  165  ,  207  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  166  ,  219  ,  160  ]  ,
      [  0  ,  136  ,  55  ]  ],
    [  [  118  ,  42  ,  131  ]  ,
      [  175  ,  141  ,  195  ]  ,
      [  231  ,  212  ,  232  ]  ,
      [  217  ,  240  ,  211  ]  ,
      [  127  ,  191  ,  123  ]  ,
      [  27  ,  120  ,  55  ]  ],
    [  [  118  ,  42  ,  131  ]  ,
      [  175  ,  141  ,  195  ]  ,
      [  231  ,  212  ,  232  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  217  ,  240  ,  211  ]  ,
      [  127  ,  191  ,  123  ]  ,
      [  27  ,  120  ,  55  ]  ],
    [  [  118  ,  42  ,  131  ]  ,
      [  153  ,  112  ,  171  ]  ,
      [  194  ,  165  ,  207  ]  ,
      [  231  ,  212  ,  232  ]  ,
      [  217  ,  240  ,  211  ]  ,
      [  166  ,  219  ,  160  ]  ,
      [  90  ,  174  ,  97  ]  ,
      [  27  ,  120  ,  55  ]  ],
    [  [  118  ,  42  ,  131  ]  ,
      [  153  ,  112  ,  171  ]  ,
      [  194  ,  165  ,  207  ]  ,
      [  231  ,  212  ,  232  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  217  ,  240  ,  211  ]  ,
      [  166  ,  219  ,  160  ]  ,
      [  90  ,  174  ,  97  ]  ,
      [  27  ,  120  ,  55  ]  ],
    [  [  64  ,  0  ,  75  ]  ,
      [  118  ,  42  ,  131  ]  ,
      [  153  ,  112  ,  171  ]  ,
      [  194  ,  165  ,  207  ]  ,
      [  231  ,  212  ,  232  ]  ,
      [  217  ,  240  ,  211  ]  ,
      [  166  ,  219  ,  160  ]  ,
      [  90  ,  174  ,  97  ]  ,
      [  27  ,  120  ,  55  ]  ,
      [  0  ,  68  ,  27  ]  ],
    [  [  64  ,  0  ,  75  ]  ,
      [  118  ,  42  ,  131  ]  ,
      [  153  ,  112  ,  171  ]  ,
      [  194  ,  165  ,  207  ]  ,
      [  231  ,  212  ,  232  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  217  ,  240  ,  211  ]  ,
      [  166  ,  219  ,  160  ]  ,
      [  90  ,  174  ,  97  ]  ,
      [  27  ,  120  ,  55  ]  ,
      [  0  ,  68  ,  27  ]  ]]

  PiYG = [
    [  [  233  ,  163  ,  201  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  161  ,  215  ,  106  ]  ],
    [  [  208  ,  28  ,  139  ]  ,
      [  241  ,  182  ,  218  ]  ,
      [  184  ,  225  ,  134  ]  ,
      [  77  ,  172  ,  38  ]  ],
    [  [  208  ,  28  ,  139  ]  ,
      [  241  ,  182  ,  218  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  184  ,  225  ,  134  ]  ,
      [  77  ,  172  ,  38  ]  ],
    [  [  197  ,  27  ,  125  ]  ,
      [  233  ,  163  ,  201  ]  ,
      [  253  ,  224  ,  239  ]  ,
      [  230  ,  245  ,  208  ]  ,
      [  161  ,  215  ,  106  ]  ,
      [  77  ,  146  ,  33  ]  ],
    [  [  197  ,  27  ,  125  ]  ,
      [  233  ,  163  ,  201  ]  ,
      [  253  ,  224  ,  239  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  230  ,  245  ,  208  ]  ,
      [  161  ,  215  ,  106  ]  ,
      [  77  ,  146  ,  33  ]  ],
    [  [  197  ,  27  ,  125  ]  ,
      [  222  ,  119  ,  174  ]  ,
      [  241  ,  182  ,  218  ]  ,
      [  253  ,  224  ,  239  ]  ,
      [  230  ,  245  ,  208  ]  ,
      [  184  ,  225  ,  134  ]  ,
      [  127  ,  188  ,  65  ]  ,
      [  77  ,  146  ,  33  ]  ],
    [  [  197  ,  27  ,  125  ]  ,
      [  222  ,  119  ,  174  ]  ,
      [  241  ,  182  ,  218  ]  ,
      [  253  ,  224  ,  239  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  230  ,  245  ,  208  ]  ,
      [  184  ,  225  ,  134  ]  ,
      [  127  ,  188  ,  65  ]  ,
      [  77  ,  146  ,  33  ]  ],
    [  [  142  ,  1  ,  82  ]  ,
      [  197  ,  27  ,  125  ]  ,
      [  222  ,  119  ,  174  ]  ,
      [  241  ,  182  ,  218  ]  ,
      [  253  ,  224  ,  239  ]  ,
      [  230  ,  245  ,  208  ]  ,
      [  184  ,  225  ,  134  ]  ,
      [  127  ,  188  ,  65  ]  ,
      [  77  ,  146  ,  33  ]  ,
      [  39  ,  100  ,  25  ]  ],
    [  [  142  ,  1  ,  82  ]  ,
      [  197  ,  27  ,  125  ]  ,
      [  222  ,  119  ,  174  ]  ,
      [  241  ,  182  ,  218  ]  ,
      [  253  ,  224  ,  239  ]  ,
      [  247  ,  247  ,  247  ]  ,
      [  230  ,  245  ,  208  ]  ,
      [  184  ,  225  ,  134  ]  ,
      [  127  ,  188  ,  65  ]  ,
      [  77  ,  146  ,  33  ]  ,
      [  39  ,  100  ,  25  ]  ]]

  BrBG = [
    [  [  216  ,  179  ,  101  ]  ,
      [  245  ,  245  ,  245  ]  ,
      [  90  ,  180  ,  172  ]  ],
    [  [  166  ,  97  ,  26  ]  ,
      [  223  ,  194  ,  125  ]  ,
      [  128  ,  205  ,  193  ]  ,
      [  1  ,  133  ,  113  ]  ],
    [  [  166  ,  97  ,  26  ]  ,
      [  223  ,  194  ,  125  ]  ,
      [  245  ,  245  ,  245  ]  ,
      [  128  ,  205  ,  193  ]  ,
      [  1  ,  133  ,  113  ]  ],
    [  [  140  ,  81  ,  10  ]  ,
      [  216  ,  179  ,  101  ]  ,
      [  246  ,  232  ,  195  ]  ,
      [  199  ,  234  ,  229  ]  ,
      [  90  ,  180  ,  172  ]  ,
      [  1  ,  102  ,  94  ]  ],
    [  [  140  ,  81  ,  10  ]  ,
      [  216  ,  179  ,  101  ]  ,
      [  246  ,  232  ,  195  ]  ,
      [  245  ,  245  ,  245  ]  ,
      [  199  ,  234  ,  229  ]  ,
      [  90  ,  180  ,  172  ]  ,
      [  1  ,  102  ,  94  ]  ],
    [  [  140  ,  81  ,  10  ]  ,
      [  191  ,  129  ,  45  ]  ,
      [  223  ,  194  ,  125  ]  ,
      [  246  ,  232  ,  195  ]  ,
      [  199  ,  234  ,  229  ]  ,
      [  128  ,  205  ,  193  ]  ,
      [  53  ,  151  ,  143  ]  ,
      [  1  ,  102  ,  94  ]  ],
    [  [  140  ,  81  ,  10  ]  ,
      [  191  ,  129  ,  45  ]  ,
      [  223  ,  194  ,  125  ]  ,
      [  246  ,  232  ,  195  ]  ,
      [  245  ,  245  ,  245  ]  ,
      [  199  ,  234  ,  229  ]  ,
      [  128  ,  205  ,  193  ]  ,
      [  53  ,  151  ,  143  ]  ,
      [  1  ,  102  ,  94  ]  ],
    [  [  84  ,  48  ,  5  ]  ,
      [  140  ,  81  ,  10  ]  ,
      [  191  ,  129  ,  45  ]  ,
      [  223  ,  194  ,  125  ]  ,
      [  246  ,  232  ,  195  ]  ,
      [  199  ,  234  ,  229  ]  ,
      [  128  ,  205  ,  193  ]  ,
      [  53  ,  151  ,  143  ]  ,
      [  1  ,  102  ,  94  ]  ,
      [  0  ,  60  ,  48  ]  ],
    [  [  84  ,  48  ,  5  ]  ,
      [  140  ,  81  ,  10  ]  ,
      [  191  ,  129  ,  45  ]  ,
      [  223  ,  194  ,  125  ]  ,
      [  246  ,  232  ,  195  ]  ,
      [  245  ,  245  ,  245  ]  ,
      [  199  ,  234  ,  229  ]  ,
      [  128  ,  205  ,  193  ]  ,
      [  53  ,  151  ,  143  ]  ,
      [  1  ,  102  ,  94  ]  ,
      [  0  ,  60  ,  48  ]  ]]

class Qualitative extends ColorSchemes
  @getScheme: (legendName) ->
    if legendName is "Accent"
      return Accent
    else if legendName is "Dark2"
      return Dark2
    else if legendName is "Paired"
      return Paired
    else if legendName is "Pastel1"
      return Pastel1
    else if legendName is "Pastel2"
      return Pastel2
    else if legendName is "Set1"
      return Set1
    else if legendName is "Set2"
      return Set2
    else if legendName is "Set3"
      return Set3

  Accent = [
    [  [  127  ,  201  ,  127  ]  ,
      [  190  ,  174  ,  212  ]  ,
      [  253  ,  192  ,  134  ]  ],
    [  [  127  ,  201  ,  127  ]  ,
      [  190  ,  174  ,  212  ]  ,
      [  253  ,  192  ,  134  ]  ,
      [  255  ,  255  ,  153  ]  ],
    [  [  127  ,  201  ,  127  ]  ,
      [  190  ,  174  ,  212  ]  ,
      [  253  ,  192  ,  134  ]  ,
      [  255  ,  255  ,  153  ]  ,
      [  56  ,  108  ,  176  ]  ],
    [  [  127  ,  201  ,  127  ]  ,
      [  190  ,  174  ,  212  ]  ,
      [  253  ,  192  ,  134  ]  ,
      [  255  ,  255  ,  153  ]  ,
      [  56  ,  108  ,  176  ]  ,
      [  240  ,  2  ,  127  ]  ],
    [  [  127  ,  201  ,  127  ]  ,
      [  190  ,  174  ,  212  ]  ,
      [  253  ,  192  ,  134  ]  ,
      [  255  ,  255  ,  153  ]  ,
      [  56  ,  108  ,  176  ]  ,
      [  240  ,  2  ,  127  ]  ,
      [  191  ,  91  ,  23  ]  ],
    [  [  127  ,  201  ,  127  ]  ,
      [  190  ,  174  ,  212  ]  ,
      [  253  ,  192  ,  134  ]  ,
      [  255  ,  255  ,  153  ]  ,
      [  56  ,  108  ,  176  ]  ,
      [  240  ,  2  ,  127  ]  ,
      [  191  ,  91  ,  23  ]  ,
      [  102  ,  102  ,  102  ]  ]]

  Dark2 = [
    [  [  27  ,  158  ,  119  ]  ,
      [  217  ,  95  ,  2  ]  ,
      [  117  ,  112  ,  179  ]  ],
    [  [  27  ,  158  ,  119  ]  ,
      [  217  ,  95  ,  2  ]  ,
      [  117  ,  112  ,  179  ]  ,
      [  231  ,  41  ,  138  ]  ],
    [  [  27  ,  158  ,  119  ]  ,
      [  217  ,  95  ,  2  ]  ,
      [  117  ,  112  ,  179  ]  ,
      [  231  ,  41  ,  138  ]  ,
      [  102  ,  166  ,  30  ]  ],
    [  [  27  ,  158  ,  119  ]  ,
      [  217  ,  95  ,  2  ]  ,
      [  117  ,  112  ,  179  ]  ,
      [  231  ,  41  ,  138  ]  ,
      [  102  ,  166  ,  30  ]  ,
      [  230  ,  171  ,  2  ]  ],
    [  [  27  ,  158  ,  119  ]  ,
      [  217  ,  95  ,  2  ]  ,
      [  117  ,  112  ,  179  ]  ,
      [  231  ,  41  ,  138  ]  ,
      [  102  ,  166  ,  30  ]  ,
      [  230  ,  171  ,  2  ]  ,
      [  166  ,  118  ,  29  ]  ],
    [  [  27  ,  158  ,  119  ]  ,
      [  217  ,  95  ,  2  ]  ,
      [  117  ,  112  ,  179  ]  ,
      [  231  ,  41  ,  138  ]  ,
      [  102  ,  166  ,  30  ]  ,
      [  230  ,  171  ,  2  ]  ,
      [  166  ,  118  ,  29  ]  ,
      [  102  ,  102  ,  102  ]  ]]

  Paired = [
    [  [  166  ,  206  ,  227  ]  ,
      [  31  ,  120  ,  180  ]  ,
      [  178  ,  223  ,  138  ]  ],
    [  [  166  ,  206  ,  227  ]  ,
      [  31  ,  120  ,  180  ]  ,
      [  178  ,  223  ,  138  ]  ,
      [  51  ,  160  ,  44  ]  ],
    [  [  166  ,  206  ,  227  ]  ,
      [  31  ,  120  ,  180  ]  ,
      [  178  ,  223  ,  138  ]  ,
      [  51  ,  160  ,  44  ]  ,
      [  251  ,  154  ,  153  ]  ],
    [  [  166  ,  206  ,  227  ]  ,
      [  31  ,  120  ,  180  ]  ,
      [  178  ,  223  ,  138  ]  ,
      [  51  ,  160  ,  44  ]  ,
      [  251  ,  154  ,  153  ]  ,
      [  227  ,  26  ,  28  ]  ],
    [  [  166  ,  206  ,  227  ]  ,
      [  31  ,  120  ,  180  ]  ,
      [  178  ,  223  ,  138  ]  ,
      [  51  ,  160  ,  44  ]  ,
      [  251  ,  154  ,  153  ]  ,
      [  227  ,  26  ,  28  ]  ,
      [  253  ,  191  ,  111  ]  ],
    [  [  166  ,  206  ,  227  ]  ,
      [  31  ,  120  ,  180  ]  ,
      [  178  ,  223  ,  138  ]  ,
      [  51  ,  160  ,  44  ]  ,
      [  251  ,  154  ,  153  ]  ,
      [  227  ,  26  ,  28  ]  ,
      [  253  ,  191  ,  111  ]  ,
      [  255  ,  127  ,  0  ]  ],
    [  [  166  ,  206  ,  227  ]  ,
      [  31  ,  120  ,  180  ]  ,
      [  178  ,  223  ,  138  ]  ,
      [  51  ,  160  ,  44  ]  ,
      [  251  ,  154  ,  153  ]  ,
      [  227  ,  26  ,  28  ]  ,
      [  253  ,  191  ,  111  ]  ,
      [  255  ,  127  ,  0  ]  ,
      [  202  ,  178  ,  214  ]  ],
    [  [  166  ,  206  ,  227  ]  ,
      [  31  ,  120  ,  180  ]  ,
      [  178  ,  223  ,  138  ]  ,
      [  51  ,  160  ,  44  ]  ,
      [  251  ,  154  ,  153  ]  ,
      [  227  ,  26  ,  28  ]  ,
      [  253  ,  191  ,  111  ]  ,
      [  255  ,  127  ,  0  ]  ,
      [  202  ,  178  ,  214  ]  ,
      [  106  ,  61  ,  154  ]  ],
    [  [  166  ,  206  ,  227  ]  ,
      [  31  ,  120  ,  180  ]  ,
      [  178  ,  223  ,  138  ]  ,
      [  51  ,  160  ,  44  ]  ,
      [  251  ,  154  ,  153  ]  ,
      [  227  ,  26  ,  28  ]  ,
      [  253  ,  191  ,  111  ]  ,
      [  255  ,  127  ,  0  ]  ,
      [  202  ,  178  ,  214  ]  ,
      [  106  ,  61  ,  154  ]  ,
      [  255  ,  255  ,  153  ]  ],
    [  [  166  ,  206  ,  227  ]  ,
      [  31  ,  120  ,  180  ]  ,
      [  178  ,  223  ,  138  ]  ,
      [  51  ,  160  ,  44  ]  ,
      [  251  ,  154  ,  153  ]  ,
      [  227  ,  26  ,  28  ]  ,
      [  253  ,  191  ,  111  ]  ,
      [  255  ,  127  ,  0  ]  ,
      [  202  ,  178  ,  214  ]  ,
      [  106  ,  61  ,  154  ]  ,
      [  255  ,  255  ,  153  ]  ,
      [  177  ,  89  ,  40  ]  ]]

  Pastel1 = [
    [  [  251  ,  180  ,  174  ]  ,
      [  179  ,  205  ,  227  ]  ,
      [  204  ,  235  ,  197  ]  ],
    [  [  251  ,  180  ,  174  ]  ,
      [  179  ,  205  ,  227  ]  ,
      [  204  ,  235  ,  197  ]  ,
      [  222  ,  203  ,  228  ]  ],
    [  [  251  ,  180  ,  174  ]  ,
      [  179  ,  205  ,  227  ]  ,
      [  204  ,  235  ,  197  ]  ,
      [  222  ,  203  ,  228  ]  ,
      [  254  ,  217  ,  166  ]  ],
    [  [  251  ,  180  ,  174  ]  ,
      [  179  ,  205  ,  227  ]  ,
      [  204  ,  235  ,  197  ]  ,
      [  222  ,  203  ,  228  ]  ,
      [  254  ,  217  ,  166  ]  ,
      [  255  ,  255  ,  204  ]  ],
    [  [  251  ,  180  ,  174  ]  ,
      [  179  ,  205  ,  227  ]  ,
      [  204  ,  235  ,  197  ]  ,
      [  222  ,  203  ,  228  ]  ,
      [  254  ,  217  ,  166  ]  ,
      [  255  ,  255  ,  204  ]  ,
      [  229  ,  216  ,  189  ]  ],
    [  [  251  ,  180  ,  174  ]  ,
      [  179  ,  205  ,  227  ]  ,
      [  204  ,  235  ,  197  ]  ,
      [  222  ,  203  ,  228  ]  ,
      [  254  ,  217  ,  166  ]  ,
      [  255  ,  255  ,  204  ]  ,
      [  229  ,  216  ,  189  ]  ,
      [  253  ,  218  ,  236  ]  ],
    [  [  251  ,  180  ,  174  ]  ,
      [  179  ,  205  ,  227  ]  ,
      [  204  ,  235  ,  197  ]  ,
      [  222  ,  203  ,  228  ]  ,
      [  254  ,  217  ,  166  ]  ,
      [  255  ,  255  ,  204  ]  ,
      [  229  ,  216  ,  189  ]  ,
      [  253  ,  218  ,  236  ]  ,
      [  242  ,  242  ,  242  ]  ]]

  Pastel2 = [
    [  [  179  ,  226  ,  205  ]  ,
      [  253  ,  205  ,  172  ]  ,
      [  203  ,  213  ,  232  ]  ],
    [  [  179  ,  226  ,  205  ]  ,
      [  253  ,  205  ,  172  ]  ,
      [  203  ,  213  ,  232  ]  ,
      [  244  ,  202  ,  228  ]  ],
    [  [  179  ,  226  ,  205  ]  ,
      [  253  ,  205  ,  172  ]  ,
      [  203  ,  213  ,  232  ]  ,
      [  244  ,  202  ,  228  ]  ,
      [  230  ,  245  ,  201  ]  ],
    [  [  179  ,  226  ,  205  ]  ,
      [  253  ,  205  ,  172  ]  ,
      [  203  ,  213  ,  232  ]  ,
      [  244  ,  202  ,  228  ]  ,
      [  230  ,  245  ,  201  ]  ,
      [  255  ,  242  ,  174  ]  ],
    [  [  179  ,  226  ,  205  ]  ,
      [  253  ,  205  ,  172  ]  ,
      [  203  ,  213  ,  232  ]  ,
      [  244  ,  202  ,  228  ]  ,
      [  230  ,  245  ,  201  ]  ,
      [  255  ,  242  ,  174  ]  ,
      [  241  ,  226  ,  204  ]  ],
    [  [  179  ,  226  ,  205  ]  ,
      [  253  ,  205  ,  172  ]  ,
      [  203  ,  213  ,  232  ]  ,
      [  244  ,  202  ,  228  ]  ,
      [  230  ,  245  ,  201  ]  ,
      [  255  ,  242  ,  174  ]  ,
      [  241  ,  226  ,  204  ]  ,
      [  204  ,  204  ,  204  ]  ]]

  Set1 = [
    [  [  228  ,  26  ,  28  ]  ,
      [  55  ,  126  ,  184  ]  ,
      [  77  ,  175  ,  74  ]  ],
    [  [  228  ,  26  ,  28  ]  ,
      [  55  ,  126  ,  184  ]  ,
      [  77  ,  175  ,  74  ]  ,
      [  152  ,  78  ,  163  ]  ],
    [  [  228  ,  26  ,  28  ]  ,
      [  55  ,  126  ,  184  ]  ,
      [  77  ,  175  ,  74  ]  ,
      [  152  ,  78  ,  163  ]  ,
      [  255  ,  127  ,  0  ]  ],
    [  [  228  ,  26  ,  28  ]  ,
      [  55  ,  126  ,  184  ]  ,
      [  77  ,  175  ,  74  ]  ,
      [  152  ,  78  ,  163  ]  ,
      [  255  ,  127  ,  0  ]  ,
      [  255  ,  255  ,  51  ]  ],
    [  [  228  ,  26  ,  28  ]  ,
      [  55  ,  126  ,  184  ]  ,
      [  77  ,  175  ,  74  ]  ,
      [  152  ,  78  ,  163  ]  ,
      [  255  ,  127  ,  0  ]  ,
      [  255  ,  255  ,  51  ]  ,
      [  166  ,  86  ,  40  ]  ],
    [  [  228  ,  26  ,  28  ]  ,
      [  55  ,  126  ,  184  ]  ,
      [  77  ,  175  ,  74  ]  ,
      [  152  ,  78  ,  163  ]  ,
      [  255  ,  127  ,  0  ]  ,
      [  255  ,  255  ,  51  ]  ,
      [  166  ,  86  ,  40  ]  ,
      [  247  ,  129  ,  191  ]  ],
    [  [  228  ,  26  ,  28  ]  ,
      [  55  ,  126  ,  184  ]  ,
      [  77  ,  175  ,  74  ]  ,
      [  152  ,  78  ,  163  ]  ,
      [  255  ,  127  ,  0  ]  ,
      [  255  ,  255  ,  51  ]  ,
      [  166  ,  86  ,  40  ]  ,
      [  247  ,  129  ,  191  ]  ,
      [  153  ,  153  ,  153  ]  ]]

  Set2 = [
    [  [  102  ,  194  ,  165  ]  ,
      [  252  ,  141  ,  98  ]  ,
      [  141  ,  160  ,  203  ]  ],
    [  [  102  ,  194  ,  165  ]  ,
      [  252  ,  141  ,  98  ]  ,
      [  141  ,  160  ,  203  ]  ,
      [  231  ,  138  ,  195  ]  ],
    [  [  102  ,  194  ,  165  ]  ,
      [  252  ,  141  ,  98  ]  ,
      [  141  ,  160  ,  203  ]  ,
      [  231  ,  138  ,  195  ]  ,
      [  166  ,  216  ,  84  ]  ],
    [  [  102  ,  194  ,  165  ]  ,
      [  252  ,  141  ,  98  ]  ,
      [  141  ,  160  ,  203  ]  ,
      [  231  ,  138  ,  195  ]  ,
      [  166  ,  216  ,  84  ]  ,
      [  255  ,  217  ,  47  ]  ],
    [  [  102  ,  194  ,  165  ]  ,
      [  252  ,  141  ,  98  ]  ,
      [  141  ,  160  ,  203  ]  ,
      [  231  ,  138  ,  195  ]  ,
      [  166  ,  216  ,  84  ]  ,
      [  255  ,  217  ,  47  ]  ,
      [  229  ,  196  ,  148  ]  ],
    [  [  102  ,  194  ,  165  ]  ,
      [  252  ,  141  ,  98  ]  ,
      [  141  ,  160  ,  203  ]  ,
      [  231  ,  138  ,  195  ]  ,
      [  166  ,  216  ,  84  ]  ,
      [  255  ,  217  ,  47  ]  ,
      [  229  ,  196  ,  148  ]  ,
      [  179  ,  179  ,  179  ]  ]]

  Set3 = [
    [  [  141  ,  211  ,  199  ]  ,
      [  255  ,  255  ,  179  ]  ,
      [  190  ,  186  ,  218  ]  ],
    [  [  141  ,  211  ,  199  ]  ,
      [  255  ,  255  ,  179  ]  ,
      [  190  ,  186  ,  218  ]  ,
      [  251  ,  128  ,  114  ]  ],
    [  [  141  ,  211  ,  199  ]  ,
      [  255  ,  255  ,  179  ]  ,
      [  190  ,  186  ,  218  ]  ,
      [  251  ,  128  ,  114  ]  ,
      [  128  ,  177  ,  211  ]  ],
    [  [  141  ,  211  ,  199  ]  ,
      [  255  ,  255  ,  179  ]  ,
      [  190  ,  186  ,  218  ]  ,
      [  251  ,  128  ,  114  ]  ,
      [  128  ,  177  ,  211  ]  ,
      [  253  ,  180  ,  98  ]  ],
    [  [  141  ,  211  ,  199  ]  ,
      [  255  ,  255  ,  179  ]  ,
      [  190  ,  186  ,  218  ]  ,
      [  251  ,  128  ,  114  ]  ,
      [  128  ,  177  ,  211  ]  ,
      [  253  ,  180  ,  98  ]  ,
      [  179  ,  222  ,  105  ]  ],
    [  [  141  ,  211  ,  199  ]  ,
      [  255  ,  255  ,  179  ]  ,
      [  190  ,  186  ,  218  ]  ,
      [  251  ,  128  ,  114  ]  ,
      [  128  ,  177  ,  211  ]  ,
      [  253  ,  180  ,  98  ]  ,
      [  179  ,  222  ,  105  ]  ,
      [  252  ,  205  ,  229  ]  ],
    [  [  141  ,  211  ,  199  ]  ,
      [  255  ,  255  ,  179  ]  ,
      [  190  ,  186  ,  218  ]  ,
      [  251  ,  128  ,  114  ]  ,
      [  128  ,  177  ,  211  ]  ,
      [  253  ,  180  ,  98  ]  ,
      [  179  ,  222  ,  105  ]  ,
      [  252  ,  205  ,  229  ]  ,
      [  217  ,  217  ,  217  ]  ],
    [  [  141  ,  211  ,  199  ]  ,
      [  255  ,  255  ,  179  ]  ,
      [  190  ,  186  ,  218  ]  ,
      [  251  ,  128  ,  114  ]  ,
      [  128  ,  177  ,  211  ]  ,
      [  253  ,  180  ,  98  ]  ,
      [  179  ,  222  ,  105  ]  ,
      [  252  ,  205  ,  229  ]  ,
      [  217  ,  217  ,  217  ]  ,
      [  188  ,  128  ,  189  ]  ],
    [  [  141  ,  211  ,  199  ]  ,
      [  255  ,  255  ,  179  ]  ,
      [  190  ,  186  ,  218  ]  ,
      [  251  ,  128  ,  114  ]  ,
      [  128  ,  177  ,  211  ]  ,
      [  253  ,  180  ,  98  ]  ,
      [  179  ,  222  ,  105  ]  ,
      [  252  ,  205  ,  229  ]  ,
      [  217  ,  217  ,  217  ]  ,
      [  188  ,  128  ,  189  ]  ,
      [  204  ,  235  ,  197  ]  ],
    [  [  141  ,  211  ,  199  ]  ,
      [  255  ,  255  ,  179  ]  ,
      [  190  ,  186  ,  218  ]  ,
      [  251  ,  128  ,  114  ]  ,
      [  128  ,  177  ,  211  ]  ,
      [  253  ,  180  ,  98  ]  ,
      [  179  ,  222  ,  105  ]  ,
      [  252  ,  205  ,  229  ]  ,
      [  217  ,  217  ,  217  ]  ,
      [  188  ,  128  ,  189  ]  ,
      [  204  ,  235  ,  197  ]  ,
      [  255  ,  237  ,  111  ]  ]]

class Sequential extends ColorSchemes
  @getScheme: (legendName) ->
    if legendName is "YlOrBr"
      return YlOrBr
    else if legendName is "Oranges"
      return Oranges
    else if legendName is "Reds"
      return Reds
    else if legendName is "YlOrRd"
      return YlOrRd
    else if legendName is "OrRd"
      return OrRd
    else if legendName is "PuRd"
      return PuRd
    else if legendName is "RdPu"
      return RdPu
    else if legendName is "BuPu"
      return BuPu
    else if legendName is "Purples"
      return Purples
    else if legendName is "PuBu"
      return PuBu
    else if legendName is "Blues"
      return Blues
    else if legendName is "GnBu"
      return GnBu
    else if legendName is "YlGnBu"
      return YlGnBu
    else if legendName is "PuBuGn"
      return PuGuGn
    else if legendName is "Greens"
      return Greens
    else if legendName is "Greys"
      return Greys

  YlOrBr = [
    [	[	255	,	247	,	188	]	,
      [	254	,	196	,	79	]	,
      [	217	,	95	,	14	]	],
    [	[	255	,	255	,	212	]	,
      [	254	,	217	,	142	]	,
      [	254	,	153	,	41	]	,
      [	204	,	76	,	2	]	],
    [	[	255	,	255	,	212	]	,
      [	254	,	217	,	142	]	,
      [	254	,	153	,	41	]	,
      [	217	,	95	,	14	]	,
      [	153	,	52	,	4	]	],
    [	[	255	,	255	,	212	]	,
      [	254	,	227	,	145	]	,
      [	254	,	196	,	79	]	,
      [	254	,	153	,	41	]	,
      [	217	,	95	,	14	]	,
      [	153	,	52	,	4	]	],
    [	[	255	,	255	,	212	]	,
      [	254	,	227	,	145	]	,
      [	254	,	196	,	79	]	,
      [	254	,	153	,	41	]	,
      [	236	,	112	,	20	]	,
      [	204	,	76	,	2	]	,
      [	140	,	45	,	4	]	],
    [	[	255	,	255	,	229	]	,
      [	255	,	247	,	188	]	,
      [	254	,	227	,	145	]	,
      [	254	,	196	,	79	]	,
      [	254	,	153	,	41	]	,
      [	236	,	112	,	20	]	,
      [	204	,	76	,	2	]	,
      [	140	,	45	,	4	]	],
    [	[	255	,	255	,	229	]	,
      [	255	,	247	,	188	]	,
      [	254	,	227	,	145	]	,
      [	254	,	196	,	79	]	,
      [	254	,	153	,	41	]	,
      [	236	,	112	,	20	]	,
      [	204	,	76	,	2	]	,
      [	153	,	52	,	4	]	,
      [	102	,	37	,	6	]	]]

  Oranges = [
    [	[	254	,	230	,	206	]	,
      [	253	,	174	,	107	]	,
      [	230	,	85	,	13	]	],
    [	[	254	,	237	,	222	]	,
      [	253	,	190	,	133	]	,
      [	253	,	141	,	60	]	,
      [	217	,	71	,	1	]	],
    [	[	254	,	237	,	222	]	,
      [	253	,	190	,	133	]	,
      [	253	,	141	,	60	]	,
      [	230	,	85	,	13	]	,
      [	166	,	54	,	3	]	],
    [	[	254	,	237	,	222	]	,
      [	253	,	208	,	162	]	,
      [	253	,	174	,	107	]	,
      [	253	,	141	,	60	]	,
      [	230	,	85	,	13	]	,
      [	166	,	54	,	3	]	],
    [	[	254	,	237	,	222	]	,
      [	253	,	208	,	162	]	,
      [	253	,	174	,	107	]	,
      [	253	,	141	,	60	]	,
      [	241	,	105	,	19	]	,
      [	217	,	72	,	1	]	,
      [	140	,	45	,	4	]	],
    [	[	255	,	245	,	235	]	,
      [	254	,	230	,	206	]	,
      [	253	,	208	,	162	]	,
      [	253	,	174	,	107	]	,
      [	253	,	141	,	60	]	,
      [	241	,	105	,	19	]	,
      [	217	,	72	,	1	]	,
      [	140	,	45	,	4	]	],
    [	[	255	,	245	,	235	]	,
      [	254	,	230	,	206	]	,
      [	253	,	208	,	162	]	,
      [	253	,	174	,	107	]	,
      [	253	,	141	,	60	]	,
      [	241	,	105	,	19	]	,
      [	217	,	72	,	1	]	,
      [	166	,	54	,	3	]	,
      [	127	,	39	,	4	]	]]

  Reds = [
    [	[	254	,	224	,	210	]	,
      [	252	,	146	,	114	]	,
      [	222	,	45	,	38	]	],
    [	[	254	,	229	,	217	]	,
      [	252	,	174	,	145	]	,
      [	251	,	106	,	74	]	,
      [	203	,	24	,	29	]	],
    [	[	254	,	229	,	217	]	,
      [	252	,	174	,	145	]	,
      [	251	,	106	,	74	]	,
      [	222	,	45	,	38	]	,
      [	165	,	15	,	21	]	],
    [	[	254	,	229	,	217	]	,
      [	252	,	187	,	161	]	,
      [	252	,	146	,	114	]	,
      [	251	,	106	,	74	]	,
      [	222	,	45	,	38	]	,
      [	165	,	15	,	21	]	],
    [	[	254	,	229	,	217	]	,
      [	252	,	187	,	161	]	,
      [	252	,	146	,	114	]	,
      [	251	,	106	,	74	]	,
      [	239	,	59	,	44	]	,
      [	203	,	24	,	29	]	,
      [	153	,	0	,	13	]	],
    [	[	255	,	245	,	240	]	,
      [	254	,	224	,	210	]	,
      [	252	,	187	,	161	]	,
      [	252	,	146	,	114	]	,
      [	251	,	106	,	74	]	,
      [	239	,	59	,	44	]	,
      [	203	,	24	,	29	]	,
      [	153	,	0	,	13	]	],
    [	[	255	,	245	,	240	]	,
      [	254	,	224	,	210	]	,
      [	252	,	187	,	161	]	,
      [	252	,	146	,	114	]	,
      [	251	,	106	,	74	]	,
      [	239	,	59	,	44	]	,
      [	203	,	24	,	29	]	,
      [	165	,	15	,	21	]	,
      [	103	,	0	,	13	]	]]

  YlOrRd = [
    [	[	255	,	237	,	160	]	,
      [	254	,	178	,	76	]	,
      [	240	,	59	,	32	]	],
    [	[	255	,	255	,	178	]	,
      [	254	,	204	,	92	]	,
      [	253	,	141	,	60	]	,
      [	227	,	26	,	28	]	],
    [	[	255	,	255	,	178	]	,
      [	254	,	204	,	92	]	,
      [	253	,	141	,	60	]	,
      [	240	,	59	,	32	]	,
      [	189	,	0	,	38	]	],
    [	[	255	,	255	,	178	]	,
      [	254	,	217	,	118	]	,
      [	254	,	178	,	76	]	,
      [	253	,	141	,	60	]	,
      [	240	,	59	,	32	]	,
      [	189	,	0	,	38	]	],
    [	[	255	,	255	,	178	]	,
      [	254	,	217	,	118	]	,
      [	254	,	178	,	76	]	,
      [	253	,	141	,	60	]	,
      [	252	,	78	,	42	]	,
      [	227	,	26	,	28	]	,
      [	177	,	0	,	38	]	],
    [	[	255	,	255	,	204	]	,
      [	255	,	237	,	160	]	,
      [	254	,	217	,	118	]	,
      [	254	,	178	,	76	]	,
      [	253	,	141	,	60	]	,
      [	252	,	78	,	42	]	,
      [	227	,	26	,	28	]	,
      [	177	,	0	,	38	]	],
    [	[	255	,	255	,	204	]	,
      [	255	,	237	,	160	]	,
      [	254	,	217	,	118	]	,
      [	254	,	178	,	76	]	,
      [	253	,	141	,	60	]	,
      [	252	,	78	,	42	]	,
      [	227	,	26	,	28	]	,
      [	189	,	0	,	38	]	,
      [	128	,	0	,	38	]	]]

  OrRd = [
    [	[	254	,	232	,	200	]	,
      [	253	,	187	,	132	]	,
      [	227	,	74	,	51	]	],
    [	[	254	,	240	,	217	]	,
      [	253	,	204	,	138	]	,
      [	252	,	141	,	89	]	,
      [	215	,	48	,	31	]	],
    [	[	254	,	240	,	217	]	,
      [	253	,	204	,	138	]	,
      [	252	,	141	,	89	]	,
      [	227	,	74	,	51	]	,
      [	179	,	0	,	0	]	],
    [	[	254	,	240	,	217	]	,
      [	253	,	212	,	158	]	,
      [	253	,	187	,	132	]	,
      [	252	,	141	,	89	]	,
      [	227	,	74	,	51	]	,
      [	179	,	0	,	0	]	],
    [	[	254	,	240	,	217	]	,
      [	253	,	212	,	158	]	,
      [	253	,	187	,	132	]	,
      [	252	,	141	,	89	]	,
      [	239	,	101	,	72	]	,
      [	215	,	48	,	31	]	,
      [	153	,	0	,	0	]	],
    [	[	255	,	247	,	236	]	,
      [	254	,	232	,	200	]	,
      [	253	,	212	,	158	]	,
      [	253	,	187	,	132	]	,
      [	252	,	141	,	89	]	,
      [	239	,	101	,	72	]	,
      [	215	,	48	,	31	]	,
      [	153	,	0	,	0	]	],
    [	[	255	,	247	,	236	]	,
      [	254	,	232	,	200	]	,
      [	253	,	212	,	158	]	,
      [	253	,	187	,	132	]	,
      [	252	,	141	,	89	]	,
      [	239	,	101	,	72	]	,
      [	215	,	48	,	31	]	,
      [	179	,	0	,	0	]	,
      [	127	,	0	,	0	]	]]

  PuRd = [
    [	[	231	,	225	,	239	]	,
      [	201	,	148	,	199	]	,
      [	221	,	28	,	119	]	],
    [	[	241	,	238	,	246	]	,
      [	215	,	181	,	216	]	,
      [	223	,	101	,	176	]	,
      [	206	,	18	,	86	]	],
    [	[	241	,	238	,	246	]	,
      [	215	,	181	,	216	]	,
      [	223	,	101	,	176	]	,
      [	221	,	28	,	119	]	,
      [	152	,	0	,	67	]	],
    [	[	241	,	238	,	246	]	,
      [	212	,	185	,	218	]	,
      [	201	,	148	,	199	]	,
      [	223	,	101	,	176	]	,
      [	221	,	28	,	119	]	,
      [	152	,	0	,	67	]	],
    [	[	241	,	238	,	246	]	,
      [	212	,	185	,	218	]	,
      [	201	,	148	,	199	]	,
      [	223	,	101	,	176	]	,
      [	231	,	41	,	138	]	,
      [	206	,	18	,	86	]	,
      [	145	,	0	,	63	]	],
    [	[	247	,	244	,	249	]	,
      [	231	,	225	,	239	]	,
      [	212	,	185	,	218	]	,
      [	201	,	148	,	199	]	,
      [	223	,	101	,	176	]	,
      [	231	,	41	,	138	]	,
      [	206	,	18	,	86	]	,
      [	145	,	0	,	63	]	],
    [	[	247	,	244	,	249	]	,
      [	231	,	225	,	239	]	,
      [	212	,	185	,	218	]	,
      [	201	,	148	,	199	]	,
      [	223	,	101	,	176	]	,
      [	231	,	41	,	138	]	,
      [	206	,	18	,	86	]	,
      [	152	,	0	,	67	]	,
      [	103	,	0	,	31	]	]]

  RdPu = [
    [	[	253	,	224	,	221	]	,
      [	250	,	159	,	181	]	,
      [	197	,	27	,	138	]	],
    [	[	254	,	235	,	226	]	,
      [	251	,	180	,	185	]	,
      [	247	,	104	,	161	]	,
      [	174	,	1	,	126	]	],
    [	[	254	,	235	,	226	]	,
      [	251	,	180	,	185	]	,
      [	247	,	104	,	161	]	,
      [	197	,	27	,	138	]	,
      [	122	,	1	,	119	]	],
    [	[	254	,	235	,	226	]	,
      [	252	,	197	,	192	]	,
      [	250	,	159	,	181	]	,
      [	247	,	104	,	161	]	,
      [	197	,	27	,	138	]	,
      [	122	,	1	,	119	]	],
    [	[	254	,	235	,	226	]	,
      [	252	,	197	,	192	]	,
      [	250	,	159	,	181	]	,
      [	247	,	104	,	161	]	,
      [	221	,	52	,	151	]	,
      [	174	,	1	,	126	]	,
      [	122	,	1	,	119	]	],
    [	[	255	,	247	,	243	]	,
      [	253	,	224	,	221	]	,
      [	252	,	197	,	192	]	,
      [	250	,	159	,	181	]	,
      [	247	,	104	,	161	]	,
      [	221	,	52	,	151	]	,
      [	174	,	1	,	126	]	,
      [	122	,	1	,	119	]	],
    [	[	255	,	247	,	243	]	,
      [	253	,	224	,	221	]	,
      [	252	,	197	,	192	]	,
      [	250	,	159	,	181	]	,
      [	247	,	104	,	161	]	,
      [	221	,	52	,	151	]	,
      [	174	,	1	,	126	]	,
      [	122	,	1	,	119	]	,
      [	73	,	0	,	106	]	]]

  BuPu = [
    [	[	224	,	236	,	244	]	,
      [	158	,	188	,	218	]	,
      [	136	,	86	,	167	]	],
    [	[	237	,	248	,	251	]	,
      [	179	,	205	,	227	]	,
      [	140	,	150	,	198	]	,
      [	136	,	65	,	157	]	],
    [	[	237	,	248	,	251	]	,
      [	179	,	205	,	227	]	,
      [	140	,	150	,	198	]	,
      [	136	,	86	,	167	]	,
      [	129	,	15	,	124	]	],
    [	[	237	,	248	,	251	]	,
      [	191	,	211	,	230	]	,
      [	158	,	188	,	218	]	,
      [	140	,	150	,	198	]	,
      [	136	,	86	,	167	]	,
      [	129	,	15	,	124	]	],
    [	[	237	,	248	,	251	]	,
      [	191	,	211	,	230	]	,
      [	158	,	188	,	218	]	,
      [	140	,	150	,	198	]	,
      [	140	,	107	,	177	]	,
      [	136	,	65	,	157	]	,
      [	110	,	1	,	107	]	],
    [	[	247	,	252	,	253	]	,
      [	224	,	236	,	244	]	,
      [	191	,	211	,	230	]	,
      [	158	,	188	,	218	]	,
      [	140	,	150	,	198	]	,
      [	140	,	107	,	177	]	,
      [	136	,	65	,	157	]	,
      [	110	,	1	,	107	]	],
    [	[	247	,	252	,	253	]	,
      [	224	,	236	,	244	]	,
      [	191	,	211	,	230	]	,
      [	158	,	188	,	218	]	,
      [	140	,	150	,	198	]	,
      [	140	,	107	,	177	]	,
      [	136	,	65	,	157	]	,
      [	129	,	15	,	124	]	,
      [	77	,	0	,	75	]	]]

  Purples = [
    [	[	239	,	237	,	245	]	,
      [	188	,	189	,	220	]	,
      [	117	,	107	,	177	]	],
    [	[	242	,	240	,	247	]	,
      [	203	,	201	,	226	]	,
      [	158	,	154	,	200	]	,
      [	106	,	81	,	163	]	],
    [	[	242	,	240	,	247	]	,
      [	203	,	201	,	226	]	,
      [	158	,	154	,	200	]	,
      [	117	,	107	,	177	]	,
      [	84	,	39	,	143	]	],
    [	[	242	,	240	,	247	]	,
      [	218	,	218	,	235	]	,
      [	188	,	189	,	220	]	,
      [	158	,	154	,	200	]	,
      [	117	,	107	,	177	]	,
      [	84	,	39	,	143	]	],
    [	[	242	,	240	,	247	]	,
      [	218	,	218	,	235	]	,
      [	188	,	189	,	220	]	,
      [	158	,	154	,	200	]	,
      [	128	,	125	,	186	]	,
      [	106	,	81	,	163	]	,
      [	74	,	20	,	134	]	],
    [	[	252	,	251	,	253	]	,
      [	239	,	237	,	245	]	,
      [	218	,	218	,	235	]	,
      [	188	,	189	,	220	]	,
      [	158	,	154	,	200	]	,
      [	128	,	125	,	186	]	,
      [	106	,	81	,	163	]	,
      [	74	,	20	,	134	]	],
    [	[	252	,	251	,	253	]	,
      [	239	,	237	,	245	]	,
      [	218	,	218	,	235	]	,
      [	188	,	189	,	220	]	,
      [	158	,	154	,	200	]	,
      [	128	,	125	,	186	]	,
      [	106	,	81	,	163	]	,
      [	84	,	39	,	143	]	,
      [	63	,	0	,	125	]	]]

  PuBu = [
    [	[	236	,	231	,	242	]	,
      [	166	,	189	,	219	]	,
      [	43	,	140	,	190	]	],
    [	[	241	,	238	,	246	]	,
      [	189	,	201	,	225	]	,
      [	116	,	169	,	207	]	,
      [	5	,	112	,	176	]	],
    [	[	241	,	238	,	246	]	,
      [	189	,	201	,	225	]	,
      [	116	,	169	,	207	]	,
      [	43	,	140	,	190	]	,
      [	4	,	90	,	141	]	],
    [	[	241	,	238	,	246	]	,
      [	208	,	209	,	230	]	,
      [	166	,	189	,	219	]	,
      [	116	,	169	,	207	]	,
      [	43	,	140	,	190	]	,
      [	4	,	90	,	141]	]	,
    [	[	241	,	238	,	246	]	,
      [	208	,	209	,	230	]	,
      [	166	,	189	,	219	]	,
      [	116	,	169	,	207	]	,
      [	54	,	144	,	192	]	,
      [	5	,	112	,	176	]	,
      [	3	,	78	,	123	]	],
    [	[	255	,	247	,	251	]	,
      [	236	,	231	,	242	]	,
      [	208	,	209	,	230	]	,
      [	166	,	189	,	219	]	,
      [	116	,	169	,	207	]	,
      [	54	,	144	,	192	]	,
      [	5	,	112	,	176	]	,
      [	3	,	78	,	123	]	],
    [	[	255	,	247	,	251	]	,
      [	236	,	231	,	242	]	,
      [	208	,	209	,	230	]	,
      [	166	,	189	,	219	]	,
      [	116	,	169	,	207	]	,
      [	54	,	144	,	192	]	,
      [	5	,	112	,	176	]	,
      [	4	,	90	,	141	]	,
      [	2	,	56	,	88	]	]]

  Blues = [
    [	[	222	,	235	,	247	]	,
      [	158	,	202	,	225	]	,
      [	49	,	130	,	189	]	],
    [	[	239	,	243	,	255	]	,
      [	189	,	215	,	231	]	,
      [	107	,	174	,	214	]	,
      [	33	,	113	,	181	]	],
    [	[	239	,	243	,	255	]	,
      [	189	,	215	,	231	]	,
      [	107	,	174	,	214	]	,
      [	49	,	130	,	189	]	,
      [	8	,	81	,	156	]	],
    [	[	239	,	243	,	255	]	,
      [	198	,	219	,	239	]	,
      [	158	,	202	,	225	]	,
      [	107	,	174	,	214	]	,
      [	49	,	130	,	189	]	,
      [	8	,	81	,	156	]	],
    [	[	239	,	243	,	255	]	,
      [	198	,	219	,	239	]	,
      [	158	,	202	,	225	]	,
      [	107	,	174	,	214	]	,
      [	66	,	146	,	198	]	,
      [	33	,	113	,	181	]	,
      [	8	,	69	,	148	]	],
    [	[	247	,	251	,	255	]	,
      [	222	,	235	,	247	]	,
      [	198	,	219	,	239	]	,
      [	158	,	202	,	225	]	,
      [	107	,	174	,	214	]	,
      [	66	,	146	,	198	]	,
      [	33	,	113	,	181	]	,
      [	8	,	69	,	148	]	],
    [	[	247	,	251	,	255	]	,
      [	222	,	235	,	247	]	,
      [	198	,	219	,	239	]	,
      [	158	,	202	,	225	]	,
      [	107	,	174	,	214	]	,
      [	66	,	146	,	198	]	,
      [	33	,	113	,	181	]	,
      [	8	,	81	,	156	]	,
      [	8	,	48	,	107	]	]]

  GnBu = [
    [	[	224	,	243	,	219	]	,
      [	168	,	221	,	181	]	,
      [	67	,	162	,	202	]	],
    [	[	240	,	249	,	232	]	,
      [	186	,	228	,	188	]	,
      [	123	,	204	,	196	]	,
      [	43	,	140	,	190	]	],
    [	[	240	,	249	,	232	]	,
      [	186	,	228	,	188	]	,
      [	123	,	204	,	196	]	,
      [	67	,	162	,	202	]	,
      [	8	,	104	,	172	]	],
    [	[	240	,	249	,	232	]	,
      [	204	,	235	,	197	]	,
      [	168	,	221	,	181	]	,
      [	123	,	204	,	196	]	,
      [	67	,	162	,	202	]	,
      [	8	,	104	,	172	]	],
    [	[	240	,	249	,	232	]	,
      [	204	,	235	,	197	]	,
      [	168	,	221	,	181	]	,
      [	123	,	204	,	196	]	,
      [	78	,	179	,	211	]	,
      [	43	,	140	,	190	]	,
      [	8	,	88	,	158	]	],
    [	[	247	,	252	,	240	]	,
      [	224	,	243	,	219	]	,
      [	204	,	235	,	197	]	,
      [	168	,	221	,	181	]	,
      [	123	,	204	,	196	]	,
      [	78	,	179	,	211	]	,
      [	43	,	140	,	190	]	,
      [	8	,	88	,	158	]	],
    [	[	247	,	252	,	240	]	,
      [	224	,	243	,	219	]	,
      [	204	,	235	,	197	]	,
      [	168	,	221	,	181	]	,
      [	123	,	204	,	196	]	,
      [	78	,	179	,	211	]	,
      [	43	,	140	,	190	]	,
      [	8	,	104	,	172	]	,
      [	8	,	64	,	129	]	]]

  YlGnBu = [
    [	[	237	,	248	,	177	]	,
      [	127	,	205	,	187	]	,
      [	44	,	127	,	184	]	],
    [	[	255	,	255	,	204	]	,
      [	161	,	218	,	180	]	,
      [	65	,	182	,	196	]	,
      [	34	,	94	,	168	]	],
    [	[	255	,	255	,	204	]	,
      [	161	,	218	,	180	]	,
      [	65	,	182	,	196	]	,
      [	44	,	127	,	184	]	,
      [	37	,	52	,	148	]	],
    [	[	255	,	255	,	204	]	,
      [	199	,	233	,	180	]	,
      [	127	,	205	,	187	]	,
      [	65	,	182	,	196	]	,
      [	44	,	127	,	184	]	,
      [	37	,	52	,	148	]	],
    [	[	255	,	255	,	204	]	,
      [	199	,	233	,	180	]	,
      [	127	,	205	,	187	]	,
      [	65	,	182	,	196	]	,
      [	29	,	145	,	192	]	,
      [	34	,	94	,	168	]	,
      [	12	,	44	,	132	]	],
    [	[	255	,	255	,	217	]	,
      [	237	,	248	,	177	]	,
      [	199	,	233	,	180	]	,
      [	127	,	205	,	187	]	,
      [	65	,	182	,	196	]	,
      [	29	,	145	,	192	]	,
      [	34	,	94	,	168	]	,
      [	12	,	44	,	132	]	],
    [	[	255	,	255	,	217	]	,
      [	237	,	248	,	177	]	,
      [	199	,	233	,	180	]	,
      [	127	,	205	,	187	]	,
      [	65	,	182	,	196	]	,
      [	29	,	145	,	192	]	,
      [	34	,	94	,	168	]	,
      [	37	,	52	,	148	]	,
      [	8	,	29	,	88	]	]]

  PuBuGn = [
    [	[	236	,	226	,	240	]	,
      [	166	,	189	,	219	]	,
      [	28	,	144	,	153	]	],
    [	[	246	,	239	,	247	]	,
      [	189	,	201	,	225	]	,
      [	103	,	169	,	207	]	,
      [	2	,	129	,	138	]	],
    [	[	246	,	239	,	247	]	,
      [	189	,	201	,	225	]	,
      [	103	,	169	,	207	]	,
      [	28	,	144	,	153	]	,
      [	1	,	108	,	89	]	],
    [	[	246	,	239	,	247	]	,
      [	208	,	209	,	230	]	,
      [	166	,	189	,	219	]	,
      [	103	,	169	,	207	]	,
      [	28	,	144	,	153	]	,
      [	1	,	108	,	89	]	],
    [	[	246	,	239	,	247	]	,
      [	208	,	209	,	230	]	,
      [	166	,	189	,	219	]	,
      [	103	,	169	,	207	]	,
      [	54	,	144	,	192	]	,
      [	2	,	129	,	138	]	,
      [	1	,	100	,	80	]	],
    [	[	255	,	247	,	251	]	,
      [	236	,	226	,	240	]	,
      [	208	,	209	,	230	]	,
      [	166	,	189	,	219	]	,
      [	103	,	169	,	207	]	,
      [	54	,	144	,	192	]	,
      [	2	,	129	,	138	]	,
      [	1	,	100	,	80	]	],
    [	[	255	,	247	,	251	]	,
      [	236	,	226	,	240	]	,
      [	208	,	209	,	230	]	,
      [	166	,	189	,	219	]	,
      [	103	,	169	,	207	]	,
      [	54	,	144	,	192	]	,
      [	2	,	129	,	138	]	,
      [	1	,	108	,	89	]	,
      [	1	,	70	,	54	]	]]

  BuGn = [
    [	[	229	,	245	,	249	]	,
      [	153	,	216	,	201	]	,
      [	44	,	162	,	95	]	],
    [	[	237	,	248	,	251	]	,
      [	178	,	226	,	226	]	,
      [	102	,	194	,	164	]	,
      [	35	,	139	,	69	]	],
    [	[	237	,	248	,	251	]	,
      [	178	,	226	,	226	]	,
      [	102	,	194	,	164	]	,
      [	44	,	162	,	95	]	,
      [	0	,	109	,	44	]	],
    [	[	237	,	248	,	251	]	,
      [	204	,	236	,	230	]	,
      [	153	,	216	,	201	]	,
      [	102	,	194	,	164	]	,
      [	44	,	162	,	95	]	,
      [	0	,	109	,	44	]	],
    [	[	237	,	248	,	251	]	,
      [	204	,	236	,	230	]	,
      [	153	,	216	,	201	]	,
      [	102	,	194	,	164	]	,
      [	65	,	174	,	118	]	,
      [	35	,	139	,	69	]	,
      [	0	,	88	,	36	]	],
    [	[	247	,	252	,	253	]	,
      [	229	,	245	,	249	]	,
      [	204	,	236	,	230	]	,
      [	153	,	216	,	201	]	,
      [	102	,	194	,	164	]	,
      [	65	,	174	,	118	]	,
      [	35	,	139	,	69	]	,
      [	0	,	88	,	36	]	],
    [	[	247	,	252	,	253	]	,
      [	229	,	245	,	249	]	,
      [	204	,	236	,	230	]	,
      [	153	,	216	,	201	]	,
      [	102	,	194	,	164	]	,
      [	65	,	174	,	118	]	,
      [	35	,	139	,	69	]	,
      [	0	,	109	,	44	]	,
      [	0	,	68	,	27	]	]]

  Greens = [
    [	[	229	,	245	,	224	]	,
      [	161	,	217	,	155	]	,
      [	49	,	163	,	84	]	],
    [	[	237	,	248	,	233	]	,
      [	186	,	228	,	179	]	,
      [	116	,	196	,	118	]	,
      [	35	,	139	,	69	]	],
    [	[	237	,	248	,	233	]	,
      [	186	,	228	,	179	]	,
      [	116	,	196	,	118	]	,
      [	49	,	163	,	84	]	,
      [	0	,	109	,	44	]	],
    [	[	237	,	248	,	233	]	,
      [	199	,	233	,	192	]	,
      [	161	,	217	,	155	]	,
      [	116	,	196	,	118	]	,
      [	49	,	163	,	84	]	,
      [	0	,	109	,	44	]	],
    [	[	237	,	248	,	233	]	,
      [	199	,	233	,	192	]	,
      [	161	,	217	,	155	]	,
      [	116	,	196	,	118	]	,
      [	65	,	171	,	93	]	,
      [	35	,	139	,	69	]	,
      [	0	,	90	,	50	]	],
    [	[	247	,	252	,	245	]	,
      [	229	,	245	,	224	]	,
      [	199	,	233	,	192	]	,
      [	161	,	217	,	155	]	,
      [	116	,	196	,	118	]	,
      [	65	,	171	,	93	]	,
      [	35	,	139	,	69	]	,
      [	0	,	90	,	50	]	],
    [	[	247	,	252	,	245	]	,
      [	229	,	245	,	224	]	,
      [	199	,	233	,	192	]	,
      [	161	,	217	,	155	]	,
      [	116	,	196	,	118	]	,
      [	65	,	171	,	93	]	,
      [	35	,	139	,	69	]	,
      [	0	,	109	,	44	]	,
      [	0	,	68	,	27	]	]]

  Greys = [
    [	[	240	,	240	,	240	]	,
      [	189	,	189	,	189	]	,
      [	99	,	99	,	99	]	],
    [	[	247	,	247	,	247	]	,
      [	204	,	204	,	204	]	,
      [	150	,	150	,	150	]	,
      [	82	,	82	,	82	]	],
    [	[	247	,	247	,	247	]	,
      [	204	,	204	,	204	]	,
      [	150	,	150	,	150	]	,
      [	99	,	99	,	99	]	,
      [	37	,	37	,	37	]	],
    [	[	247	,	247	,	247	]	,
      [	217	,	217	,	217	]	,
      [	189	,	189	,	189	]	,
      [	150	,	150	,	150	]	,
      [	99	,	99	,	99	]	,
      [	37	,	37	,	37	]	],
    [	[	247	,	247	,	247	]	,
      [	217	,	217	,	217	]	,
      [	189	,	189	,	189	]	,
      [	150	,	150	,	150	]	,
      [	115	,	115	,	115	]	,
      [	82	,	82	,	82	]	,
      [	37	,	37	,	37	]	],
    [	[	255	,	255	,	255	]	,
      [	240	,	240	,	240	]	,
      [	217	,	217	,	217	]	,
      [	189	,	189	,	189	]	,
      [	150	,	150	,	150	]	,
      [	115	,	115	,	115	]	,
      [	82	,	82	,	82	]	,
      [	37	,	37	,	37	]	],
    [	[	255	,	255	,	255	]	,
      [	240	,	240	,	240	]	,
      [	217	,	217	,	217	]	,
      [	189	,	189	,	189	]	,
      [	150	,	150	,	150	]	,
      [	115	,	115	,	115	]	,
      [	82	,	82	,	82	]	,
      [	37	,	37	,	37	]	,
      [	0	,	0	,	0	]	]]

module.exports = {

  init: (workspace) ->

    getMyColor = () ->
      self = workspace.selfManager.self()
      mycolor = self.getVariable("color")
      if(mycolor is undefined) # called by a patch
        mycolor = self.getVariable("pcolor")
      return toColorList(mycolor)

    setMyColor = (mycolor) ->
      self = workspace.selfManager.self()
      if(self.getVariable("color") is undefined)
        self.setVariable("pcolor", mycolor)
      else
        self.setVariable("color", mycolor)

    # PRIMS #

    #alpha/trapnsparency
    alphaof = (color) ->
      if typeof color is "number"
        return 255
      validateRGB(color)
      if(color.length is 4)
        return color[3]
      return 255

    transparencyof = (color) ->
      return (1 - alphaof(color) / 255.0) * 100.0

    withalpha = (color, newVal) ->
      if(newVal < 0 or newVal > 255)
        throw exceptions.extension("Alpha must be in the range from 0 to 255.")
      if(typeof color is "number")
        color = Color.colorToRGB(color)
      validateRGB(color)
      color[3] = newVal
      return color

    withtransparency = (color, newVal) ->
      if(newVal < 0 or newVal > 100)
        throw exceptions.extension("Transparency must be in the range from 0 to 100.")
      newVal = (1.0 - newVal / 100.0) * 255.0
      return withalpha(color, newVal)

    getalpha = () ->
      self = workspace.selfManager.self()
      mycolor = self.getVariable("color")
      if(mycolor is undefined) # called by a patch
        return 255
      return alphaof(mycolor)

    gettransparency = () ->
      return  (1 - getalpha() / 255.0) * 100.0

    setalpha = (newVal) ->
      self = workspace.selfManager.self()
      mycolor = self.getVariable("color")
      if(mycolor is undefined) # called by a patch
        throw exceptions.extension("The alpha/transparency of patches cannot be changed.")
      setMyColor(withalpha(mycolor, newVal))
      return

    settransparency = (newVal) ->
      self = workspace.selfManager.self()
      mycolor = self.getVariable("color")
      if(mycolor is undefined) # called by a patch
        throw exceptions.extension("The alpha/transparency of patches cannot be changed.")
      setMyColor(withtransparency(mycolor, newVal))

    #HSB
    hueof = (color) ->
      return extractHSB(color, 0)

    saturationof = (color) ->
      return extractHSB(color, 1)

    brightnessof = (color) ->
      return extractHSB(color, 2)

    withhue = (color, newVal) ->
      newVal = modDouble(newVal, 360)
      return hsbUpdated(color, newVal, 0)

    withsaturation = (color, newVal) ->
      newVal = Math.max(Math.min(newVal, 100), 0)
      return hsbUpdated(color, newVal, 1)

    withbrightness = (color, newVal) ->
      newVal = Math.max(Math.min(newVal, 100), 0)
      return hsbUpdated(color, newVal, 2)

    gethue = () ->
      hueof(getMyColor())

    getsaturation = () ->
      saturationof(getMyColor())

    getbrightness = () ->
      brightnessof(getMyColor())

    sethue = (number) ->
      if(number < 0 or number > 360)
        throw exceptions.extension("Hue must be in the range from 0 to 360.")
      setMyColor(withhue(getMyColor(), number))

    setsaturation = (number) ->
      if(number < 0 or number > 100)
        throw exceptions.extension("Saturation must be in the range from 0 to 100.")
      setMyColor(withsaturation(getMyColor(), number))

    setbrightness = (number) ->
      if(number < 0 or number > 100)
        throw exceptions.extension("Brightness must be in the range from 0 to 100.")
      setMyColor(withbrightness(getMyColor(), number))

    #RGB
    redof = (color) ->
      extractRGB(color, 0)

    greenof = (color) ->
      extractRGB(color, 1)

    blueof = (color) ->
      extractRGB(color, 2)

    withred = (color, newVal) ->
      if(newVal < 0 or newVal > 255)
        throw exceptions.extension("Value must be in the range from 0 to 255.")
      rgbUpdated(color, newVal, 0)

    withgreen = (color, newVal) ->
      if(newVal < 0 or newVal > 255)
        throw exceptions.extension("Value must be in the range from 0 to 255.")
      rgbUpdated(color, newVal, 1)

    withblue = (color, newVal) ->
      if(newVal < 0 or newVal > 255)
        throw exceptions.extension("Value must be in the range from 0 to 255.")
      rgbUpdated(color, newVal, 2)

    getred = () ->
      mycolor = getMyColor()
      return mycolor[0]

    getgreen = () ->
      mycolor = getMyColor()
      return mycolor[1]

    getblue = () ->
      mycolor = getMyColor()
      return mycolor[2]

    setred = (number) ->
      mycolor = getMyColor()
      setMyColor(withred(mycolor, number))
      return

    setgreen = (number) ->
      mycolor = getMyColor()
      setMyColor(withgreen(mycolor, number))
      return

    setblue = (number) ->
      mycolor = getMyColor()
      setMyColor(withblue(mycolor, number))
      return

    #Gradients and schemes
    scalegradienthsb = (colorList, number, min, max) -> # takes HSB colors as input
      SIZE = 256
      for color in colorList
        validateHSB(color)

      index = getIndex(number, min, max, colorList.length, SIZE)
      gradientArray = [[],[]]

      for x in [0...colorList.length - 1]
        color1 = colorList[x]
        color2 = colorList[x + 1]
        gradient = colorHSBArray(color1, color2, SIZE)
        for j in [0...SIZE]
          gradientArray[j + SIZE * x] = Color.hsbToRGB(gradient[j][0], gradient[j][1], gradient[j][2])
      return gradientArray[index]

    scalegradient = (colorList, number, min, max) ->
      SIZE = 256
      for color in colorList
        validateRGB(color)

      index = getIndex(number, min, max, colorList.length, SIZE)
      gradientArray = [[],[]]

      for x in [0...colorList.length - 1]
        color1 = colorList[x]
        color2 = colorList[x + 1]
        gradient = colorRGBArray(color1, color2, SIZE)
        for j in [0...SIZE]
          gradientArray[j + SIZE * x] = gradient[j]
      return gradientArray[index]

    scalescheme = (schemename, legendname, size, number, min, max) ->
      index = getIndex(number, min, max, 0, size)
      legend = ColorSchemes.getRGBArray(schemename, legendname, size)
      return legend[index]

    schemecolors = (schemename, legendname, size) ->
      return ColorSchemes.getRGBArray(schemename, legendname, size)





    {
      name: "palette"
    , prims: {
        "ALPHA-OF": alphaof
    ,   "TRANSPARENCY-OF": transparencyof
    ,   "ALPHA": getalpha
    ,   "SET-ALPHA": setalpha
    ,   "TRANSPARENCY": gettransparency
    ,   "SET-TRANSPARENCY": settransparency
    ,   "WITH-ALPHA": withalpha
    ,   "WITH-TRANSPARENCY": withtransparency
    ,   "HUE-OF": hueof
    ,   "SATURATION-OF": saturationof
    ,   "BRIGHTNESS-OF": brightnessof
    ,   "WITH-HUE": withhue
    ,   "WITH-SATURATION": withsaturation
    ,   "WITH-BRIGHTNESS": withbrightness
    ,   "HUE": gethue
    ,   "SATURATION": getsaturation
    ,   "BRIGHTNESS": getbrightness
    ,   "SET-HUE": sethue
    ,   "SET-SATURATION": setsaturation
    ,   "SET-BRIGHTNESS": setbrightness
    ,   "R-OF": redof
    ,   "G-OF": greenof
    ,   "B-OF": blueof
    ,   "WITH-R": withred
    ,   "WITH-G": withgreen
    ,   "WITH-B": withblue
    ,   "R": getred
    ,   "G": getgreen
    ,   "B": getblue
    ,   "SET-R": setred
    ,   "SET-G": setgreen
    ,   "SET-B": setblue
    ,   "SCALE-GRADIENT-HSB": scalegradienthsb
    ,   "SCALE-GRADIENT": scalegradient
    ,   "SCALE-SCHEME": scalescheme
    ,   "SCHEME-COLORS": schemecolors
      }
    }
}

#Apache-Style Software License for ColorBrewer software and ColorBrewer Color Schemes
#Version 1.1
#
#Copyright (c) 2002 Cynthia Brewer, Mark Harrower, and The Pennsylvania State University. All rights reserved.
#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#1. Redistributions as source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#2. The end-user documentation included with the redistribution, if any, must include the following acknowledgment:
#This product includes color specifications and designs developed by Cynthia Brewer (http://colorbrewer.org/).
#Alternately, this acknowledgment may appear in the software itself, if and wherever such third-party acknowledgments normally appear.
#4. The name "ColorBrewer" must not be used to endorse or promote products derived from this software without prior written permission. For written permission, please
#contact Cynthia Brewer at cbrewer@psu.edu.
#5. Products derived from this software may not be called "ColorBrewer", nor may "ColorBrewer" appear in their name, without prior written permission of Cynthia Brewer.
#
#THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CYNTHIA BREWER, MARK HARROWER, OR THE
#PENNSYLVANIA STATE UNIVERSITY BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
#BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
#CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
#WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
