# d3d12book

Sample code and my exercise solutions for the book "Introduction to 3D Game Programming with DirectX 12".



Shader Model is updated to 5.1 and some simple exercises may be omitted or merged together.



## Samples

* Chapter 01 Vector Algebra
  * *XMVECTOR* : Sample usage of DirectX math vector.
* Chapter 02 Matrix Algebra
  * *XMMATRIX* : Sample usage of DirectX math matrix.
* Chapter 04 Direct3D Initialization
  * *Init Direct3D* : Sample application framework.
* Chapter 06 Drawing in Direct3D 
  * *Box* : Render a colored box with movable camera.
* Chapter 07 Drawing in Direct3D Part II
  * *Shapes* ：Render a scene composed of spheres, cylinders, a box and a grid.
  * *Land and Waves* :  Emulate rolling land and waving water by modifying the grid. To draw waves, `Dynamic Vertex Buffer` is used to update vertex positions on CPU side as time passes.
* Chapter 08 Lighting
  * *LitColumns* : ...
  * *LitWaves* : ...
* ...



## Exercises

* Chapter 06 Drawing in Direct3D
  * [x] *Exercise_06_02*

    > Now vertex position and color data are separated into two structures, towards different input slot. Therefore, some *Common* data structure and functions need to be modified (affected files are separated in directory *Common modified*). And there should be two vertex data buffers for position and color.

  * [x] *Exercise_06_03*

    > Draw point list, line strip, line list, triangle strip, triangle list in the same scene. To draw different primitives, create pipeline state objects (PSOs) for point, line, triangle respectively during initialization. Then before each draw call, set proper PSO and primitive topology argument.

  * [x] *Exercise_06_07*
  
    > Draw a box and a pyramid one-by-one with merged vertex and index buffer in the same scene. Similar to exercise *Exercise_06_03*. Also implement color changing in pixel shader after adding a `gTime` constant buffer variable.
  
* Chapter 07 Drawing in Direct3D Part II

  * [x] *Exercise_07_02*

    > Modify the *Shapes* demo to use sixteen root constants to set the per-object world matrix instead of a descriptor table. Now we only need constant buffer views (CBVs) for each frame. The root signature and resource binding before drawcall should be modified, as well as the world matrix struct in shader file. 

  * [x] *Exercise_07_03*

    > Render a skull model above a platform. The vertex and index lists needed are in *Model/skull.txt*. The color of each vertex on the skull is based on the normal of the vertex. Note that the index count of skull is over 65536, which means we need to change `uint16_t` into `uint32_t`.

* Chapter 08 Lighting

  * [ ] ...

* ...

