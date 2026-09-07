import { useMemo } from "react";
import { renderBodyMapSvg } from "./assets/bodymap.js";

export default function BodyMapVisual({ values, title }) {
  const svg = useMemo(() => renderBodyMapSvg({ values, title }), [title, values]);
  return <div className="bodymap-shell" dangerouslySetInnerHTML={{ __html: svg }} />;
}
