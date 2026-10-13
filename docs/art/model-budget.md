# Model budget

Geometry tricks to assess for every model a round makes or changes. In the
handoff, list which apply and estimate the triangle and frame-time savings of
each.

- **Sculpt high, bake low:** bake normal, AO and curvature maps from a dense
  sculpt onto a 5-15k-triangle mesh.
- **Import LODs:** Godot's generated mesh LODs, plus visibility ranges for
  distant copies.
- **Silhouette geometry:** real chips and breaks on the outline; flat faces
  get their detail from textures.
- **Rigid parts on bones:** pieces that shouldn't bend (masonry, armour) as
  separate meshes on `BoneAttachment3D`s rather than skinned.
- **Parallax depth:** a height map in the material for pits and cracks.
- **Vertex-colour grime:** crevice darkness baked into vertex colours.
