# StructuralDesignOptimization.jl

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
    A -->|Columns| B["Identify appropriate sections \n based on typical practical considerations"]
    A -->|Beams| C["Identify appropriate sections \n based on typical practical considerations"]
    B --> D["Extract section properties"]
    C --> E["Extract section properties"]
    D --> F["Generate enveloping constraints"]
    D --> G["Generate box constraints"]
    E --> H["Generate enveloping constraints"]
    E --> I["Generate box constraints"]
    F -->|Optional| J["Reduce the number of enveloping constraints \n by removing the constraints corresponding \n to faces of a convex hull with small surface areas"]
    H -->|Optional| K["Reduce the number of enveloping constraints \n by removing the constraints corresponding \n to faces of a convex hull with small surface areas"]
```

## Generating Stress Constraints

```mermaid
flowchart TB
    A["Given a section"]
    A --> B["Compute its nominal compressive \n resistance $$\phi_{c} P_{n}$$"]
    A --> C["Compute its nominal flexural \n resistance $$\phi_{b} M_{n}$$"]
```