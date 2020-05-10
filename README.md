# d3d12book

Sample code and my exercise solutions for the book "Introduction to 3D Game Programming with DirectX 12"



## Samples

* Chapter 01 Vector Algebra
  * *XMVECTOR* : Sample usage of DirectX math vector
* Chapter 02 Matrix Algebra
  * *XMMATRIX* : Sample usage of DirectX math matrix
* Chapter 04 Direct3D Initialization
  * *Init Direct3D* : Sample application framework
* Chapter 06 Drawing in Direct3D 
  * *Box* : Render a colored box with movable camera (update to Shader Model 5.1)
* ...



## Exercises

* Chapter 06 Drawing in Direct3D
  * [x] *Exercise_06_02*

    > Now vertex position and color data are separated into two structures, towards different input slot. Therefore, some *Common* data structure and functions need to be modified (affected files are separated in directory *Common modified*). And there should be two vertex data buffers for position and color.

  * [x] *Exercise_06_03*

    > Draw point list, line strip, line list, triangle strip, triangle list in the same scene. To draw different primitives, create pipeline state objects (PSOs) for point, line, triangle respectively during initialization. Then before each draw call, set proper PSO and primitive topology argument.

  * [x] *Exercise_06_07*
  
    > Draw a box and a pyramid one-by-one with merged vertex and index buffer in the same scene. Similar to exercise *Exercise_06_03*. Also implement color changing by adding a `gTime` constant buffer variable mentioned in *Exercise_06_06*.
  
  * [ ] *Exercise_06_12*
* ...