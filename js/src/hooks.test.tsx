import { act, cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { setPage } from "./store.js";
import { usePage, usePageProps, useSharedProps } from "./hooks.js";

afterEach(cleanup);

function PageProbe() {
  const page = usePage();
  return <div data-testid="probe">{page.component}</div>;
}

describe("usePage", () => {
  it("returns the current page and re-renders on updates", () => {
    setPage({ component: "orders/index", props: {}, url: "/orders", version: "v1" });
    render(<PageProbe />);
    expect(screen.getByTestId("probe").textContent).toBe("orders/index");

    act(() => {
      setPage({ component: "orders/show", props: {}, url: "/orders/1", version: "v1" });
    });
    expect(screen.getByTestId("probe").textContent).toBe("orders/show");
  });
});

interface OrdersIndexProps {
  totalCount: number;
}

function TypedProbe() {
  const props = usePageProps<OrdersIndexProps>("orders/index");
  return <div data-testid="typed">{props.totalCount}</div>;
}

function MismatchProbe() {
  usePageProps("orders/show");
  return null;
}

describe("usePageProps", () => {
  it("returns props cast to the expected type", () => {
    setPage({ component: "orders/index", props: { totalCount: 5 }, url: "/orders", version: "v1" });
    render(<TypedProbe />);
    expect(screen.getByTestId("typed").textContent).toBe("5");
  });

  it("throws when the current component does not match", () => {
    setPage({ component: "orders/index", props: {}, url: "/orders", version: "v1" });
    expect(() => render(<MismatchProbe />)).toThrow(/orders\/show/);
  });
});

interface SharedProps {
  currentUser: string;
}

function SharedProbe() {
  const shared = useSharedProps<SharedProps>();
  return <div data-testid="shared">{shared.currentUser}</div>;
}

describe("useSharedProps", () => {
  it("returns shared props cast to the expected type", () => {
    setPage({
      component: "orders/index",
      props: {},
      url: "/orders",
      version: "v1",
      shared: { currentUser: "ada" },
    });
    render(<SharedProbe />);
    expect(screen.getByTestId("shared").textContent).toBe("ada");
  });

  it("throws a descriptive error when shared props are absent", () => {
    setPage({ component: "orders/index", props: {}, url: "/orders", version: "v1" });
    expect(() => render(<SharedProbe />)).toThrow(/shared/i);
  });
});
