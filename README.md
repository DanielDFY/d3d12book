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
  * *LitWaves* : This demo is based on the *Land and Waves* demo from the previous chapter. It uses one directional light to represent the sun. The user can rotate the sun position using the left, right, up, and down arrow keys. 
  * *LitColumns* : This demo is based on the *Shapes* demo from the previous chapter, adding materials and a three-point lighting system.
* Chapter 09 Texturing
  * *Crate* : Render a cube with a crate texture.
  * *TexColumns* : This demo is based on the *LitColumns* demo from the previous chapter, adding textures to the ground, columns and spheres.
  * *TexWaves* : This demo is based on the *LitWaves* demo from the previous chapter, adding textures to the land and water. Also the water texture scrolls over the water geometry as a function of time.
* Chapter 10 Blending
  * BlendDemo : This demo is based on the *TexWaves* demo from the previous chapter, adding blending effect to the land and water. Also add fog to the scene.
* Chapter 11 Stenciling
  * StencilDemo : Render a scene with a wall, a floor, a mirror and a skull. The mirror can reflect the skull and the shadow of the skull is on the floor.
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

  * [x] *Exercise_08_01*

    > Modify the *LitWaves* demo so that the directional light only emits mostly red light. In addition, make the strength of the light oscillate as a function of time using the sine function so that the light appears to pulse. Also change the roughness in the materials as the same way.
    
  * [x] *Exercise_08_04*

    > Modify the *LitColumns* demo by removing the three-point lighting, adding a point centered about each sphere above the columns, or adding a spotlight centered about each sphere above the columns and aiming down. Press "1" to switch between these two mode. 

  * [x] *Exercise_08_06*

    > Modify the *LitWaves* demo to use the sort of cartoon shading as follows:
    >
    > <img src=".\Chapter 08 Lighting\Exercise_08_06\cartoon shading function.png" alt="cartoon shading function"/>
    >
    > k<sub>d</sub> for each element in diffuse albedo.
    >
    > k<sub>s</sub> for each element in specular albedo.
    >
    > (Note: The functions f and g above are just sample functions to start with, and can be tweaked until we get the results we want.)

* Chapter 09 Texturing

  * [x] *Exercise_09_03*

    > Modify the *Crate* demo by combining two source textures(`flare.dds` and `flarealpha.dds`) in a pixel shader to produce a fireball texture over each cube face, and rotate the flare texture around its center as a function of time.

* Chapter 11 Stenciling

  * [x] *Exercise_11_07*

    > Modify the *Blend* demo from Chapter 10 to draw a cylinder (with no caps) at the center of the scene. Texture the cylinder with the 60 frame animated electric bolt animation using additive blending. We can set a member variable for current texture index. In each draw call, get the proper texture image indicated by this index and increase it for next draw call (using modulus operation to loop the index).
    
  * [x] *Exercise_11_08*

    > Render the depth complexity of the scene used in the *Blend* demo from Chapter 10. First draw the original scene while using stencil buffer as the depth complexity counter buffer(set `StencilFunc` to `D3D12_COMPARISON_FUNC_ALWAYS` to pass all stencil tests and set `StencilPassOp` to `D3D12_STENCIL_OP_INCR` to increase the value in stencil buffer every time a pixel fragment is processed). Then, after the frame has been drawn, visualize the depth complexity by associating a special color for each level of depth complexity.
    >
    > For each level of depth complexity k: set the stencil comparison function to `D3D12_COMPARISON_EQUAL` , set all the test operations to `D3D12_STENCIL_OP_KEEP` to prevent changing any counters, and set the stencil reference value to k (Also set `DepthFunc` to `D3D12_COMPARISON_FUNC_ALWAYS` and set `DepthWriteMask` to `D3D12_DEPTH_WRITE_MASK_ZERO` to pass all depth test will not changing any depth value), and then draw a quad of color c<sub>k</sub> that covers the entire projection window. Note that this will only color the pixels that have a depth complexity of k because of the preceding set stencil comparison function and reference value.

  * [x] *Exercise_11_09*

    > Another way to implement depth complexity visualization is to use additive blending. First clear the back buffer black and disable the depth test(pass all tests). Next, set the source and
    > destination blend factors both to `D3D12_BLEND_ONE`, and the blend operation to `D3D12_BLEND_OP_ADD` so that the blending equation looks like C = C<sub>src</sub> + C<sub>dst</sub>. Now render all the objects in the scene with a pixel shader that outputs a low intensity color like (0.05, 0.05, 0.05). The more overdraw a pixel has, the more of these low intensity colors will be summed in, thus increasing the brightness of the pixel. Thus by looking at the intensity of each pixel after rendering the scene, we obtain an idea of the scene depth complexity.

  * [ ] *Exercise_11_11*

    > Modify the *Mirror* demo to reflect the floor into the mirror in addition to the skull.

* [ ] ...

