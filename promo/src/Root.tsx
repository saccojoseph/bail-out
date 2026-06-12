import React from "react";
import { Composition } from "remotion";
import { Promo, TOTAL_FRAMES } from "./Promo";

export const RemotionRoot: React.FC = () => (
  <Composition
    id="BailPromo"
    component={Promo}
    durationInFrames={TOTAL_FRAMES}
    fps={30}
    width={1080}
    height={1920}
  />
);
