# StructuralDesignOptimization.jl

This repository aims to reconstruct the two-step structural design optimization scheme developed in this [journal article](https://ascelibrary.org/doi/epdf/10.1061/%28ASCE%290733-9445%281988%29114%3A5%281120%29) using more modern tools. Most notably, the following tools are used:

- Polyhedra.jl: Generating enveloping constraints.
- Optimization.jl: Performing continuous optimization.

## Roadmap

- [x] Identify sets of appropriate sections for beam and column members from the Steel Construction Manual that are both non-slender in compression and compact in flexure based on the typical practical considerations.
  - Identify the set of sections that are both non-slender in compression and compact in flexure.
  - Reduce the set into two sets for beam and column members, respectively, based on the typical practical considerations.
- [x] Generate enveloping constraints using the section properties ($A_{g}$, $I_{x}$, $Z_{x}$) of these sets of appropriate sections.
  - If the number of the enveloping constraints was reduced in any way, generate box constraints as well.
- [x] Generate stress constraints based on the beam-column interaction equations.
  - Compute the available strengths for each member in a frame ($\varphi_{c} P_{n}$, $\varphi_{b} M_{n}$).
  - Evaluate the FE model of the frame and extract the required strengths for each member ($P_{r}$, $M_{r}$).
  - Evaluate the beam-column interaction equation for each member.
- [ ] Compile most of this functionality into a reusable package.

## Typical Practical Considerations

- Since most the structural analysis software cannot account for the local buckling limit states, the choice of appropriate sections is limited to ones that are non-slender in compression and compact in flexure.
- Choice of appropriate sections for beams is unrestricted.
- Choice of appropriate sections for columns is restricted to W8X... - W14X... sections.
- Beams on the same floor must have the same sections.
- Outer columns on the same floor must have the same sections.
- Inner columns on the same floor must have the same sections.

## Generating Geometric Constraints

```mermaid
flowchart TB
    A["Identify non-slender (compression) and compact (flexure) sections \n from the Steel Construction Manual"]
    A -->|Beams| B["Identify appropriate sections \n based on typical practical considerations"]
    A -->|Columns| C["Identify appropriate sections \n based on typical practical considerations"]
    B --> D["Extract section properties"]
    C --> E["Extract section properties"]
    D --> F["Generate enveloping constraints"]
    E --> G["Generate enveloping constraints"]
    F -->|Optional| H["Reduce the number of enveloping constraints \n by removing the constraints corresponding \n to faces of a convex hull with small surface areas"]
    G -->|Optional| I["Reduce the number of enveloping constraints \n by removing the constraints corresponding \n to faces of a convex hull with small surface areas"]
    H --> J["Generate box constraints"]
    I --> K["Generate box constraints"]
```

## Stress Constraints

```mermaid
flowchart TB
    A["Given the results of \n the second-order elastic analysis"]
    A --> B["Extract the required \n compressive strength \n for each member of a frame"]
    A --> C["Extract the required \n flexural strength \n for each member of a frame"]
    D["Compute the available \n flexural strength \n for each member of a frame"]
    E["Compute the available \n compressive strength \n for each member of a frame"]
    F["Evaluate the beam-column interaction \n equation for each member"]
    B --> F
    C --> F
    D --> F
    E --> F
```